import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../Services/config_service.dart';

/// OpenAI calls for LawHubb Assistant + find-lawyer classification.
/// API key is read from Firebase Remote Config [`openai_api_key`].
class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Shown when the key is missing, quota is exceeded, or the API is down.
  static const String unavailableMessage =
      'This functionality is currently not available. Please try again later.';

  static bool get isConfigured => _apiKey(ConfigService()).isNotEmpty;

  /// Remote Config `openai_api_key`, then legacy keys / local .env fallback.
  static String _apiKey(ConfigService config) {
    final rc = config.openAiApiKey.trim();
    if (rc.isNotEmpty) return rc;
    final legacy = config.openAiApiKey1.trim();
    if (legacy.isNotEmpty) return legacy;
    return (dotenv.env['OPENAI_API_KEY'] ?? dotenv.env['OPENAI_API_KEY1'] ?? '')
        .trim();
  }

  /// Standard API keys work with Bearer auth only — no project header.
  static Map<String, String> _headers(ConfigService config) {
    return {
      'Authorization': 'Bearer ${_apiKey(config)}',
      'Content-Type': 'application/json',
    };
  }

  static bool _responseIndicatesUnavailable(dynamic data) {
    if (data is! Map) return false;
    final error = data['error'];
    if (error is! Map) return false;
    final code =
        '${error['code'] ?? ''} ${error['type'] ?? ''}'.toLowerCase();
    final message = '${error['message'] ?? ''}'.toLowerCase();
    return code.contains('quota') ||
        code.contains('billing') ||
        code.contains('insufficient') ||
        code.contains('invalid_project') ||
        code.contains('invalid_api_key') ||
        message.contains('quota') ||
        message.contains('billing') ||
        message.contains('exceeded') ||
        message.contains('insufficient') ||
        message.contains('no such project');
  }

  static bool _isServiceUnavailable(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 ||
        status == 402 ||
        status == 403 ||
        status == 429 ||
        status == 500 ||
        status == 503) {
      return true;
    }
    if (_responseIndicatesUnavailable(e.response?.data)) {
      return true;
    }
    return false;
  }

  static String _messageForUser(DioException e) {
    if (_isServiceUnavailable(e)) {
      return unavailableMessage;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Unable to reach the assistant. Check your internet connection and try again.';
      case DioExceptionType.cancel:
        return 'The request was interrupted. Please try again.';
      default:
        break;
    }
    return unavailableMessage;
  }

  static String? _extractAssistantText(dynamic data) {
    if (data is! Map) return null;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final choice = choices[0];
    if (choice is! Map) return null;
    final message = choice['message'];
    if (message is! Map) return null;
    final content = message['content'];
    if (content == null) return null;
    final text = content.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Future<String?> _postChat({
    required List<Map<String, String>> messages,
    required int maxTokens,
    required double temperature,
  }) async {
    final config = ConfigService();
    if (_apiKey(config).isEmpty) {
      return null;
    }

    try {
      final response = await Dio().post(
        _baseUrl,
        options: Options(headers: _headers(config)),
        data: {
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': temperature,
        },
      );

      final data = response.data;
      if (_responseIndicatesUnavailable(data)) {
        return null;
      }
      return _extractAssistantText(data);
    } on DioException catch (e) {
      debugPrint('OpenAI DioException: ${e.response?.data ?? e.message}');
      if (_isServiceUnavailable(e)) {
        return null;
      }
      rethrow;
    }
  }

  /// Chat replies for LawHubb Assistant (longer output).
  static Future<String> sendMessage(String message) async {
    if (!isConfigured) {
      return unavailableMessage;
    }

    try {
      final text = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You are LawHubb Assistant for LawHubb. You help users in Ghana understand legal topics in plain language. '
                'Be concise, structured, and practical. Format replies with markdown: use **bold** for key terms, numbered lists for steps, and bullet lists for options. '
                'Do not claim to be a lawyer or give guaranteed outcomes. '
                'When unsure, suggest consulting a qualified lawyer through the app.',
          },
          {'role': 'user', 'content': message},
        ],
        maxTokens: 600,
        temperature: 0.55,
      );

      if (text == null) {
        return unavailableMessage;
      }
      return text;
    } on DioException catch (e) {
      return _messageForUser(e);
    } catch (e, st) {
      debugPrint('OpenAI error: $e\n$st');
      return unavailableMessage;
    }
  }

  /// Short classification for practice matching (find lawyer).
  /// Returns `null` when the service is unavailable; empty string when no label could be parsed.
  static Future<String?> classifyPractice({
    required String userQuery,
    required List<String> practiceNames,
  }) async {
    if (!isConfigured) {
      return null;
    }

    final list = practiceNames.join(', ');
    final prompt =
        'You must choose exactly ONE practice area from this list that best matches the user issue. '
        'Reply with ONLY that practice area, nothing else — no quotes, no punctuation, no explanation.\n'
        'List: $list\n'
        'User issue: $userQuery';

    try {
      final text = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You map user legal questions to one practice label from a fixed list. Output only the label.',
          },
          {'role': 'user', 'content': prompt},
        ],
        maxTokens: 40,
        temperature: 0.1,
      );

      if (text == null) {
        return null;
      }
      return text;
    } on DioException catch (e) {
      debugPrint('OpenAI classifyPractice: ${e.response?.data ?? e.message}');
      if (_isServiceUnavailable(e)) {
        return null;
      }
      return '';
    } catch (e) {
      debugPrint('OpenAI classifyPractice error: $e');
      return null;
    }
  }

  /// Emergency / first-aid style guidance (uses same Remote Config key).
  static Future<String> sendEmergencyGuidance(String query) async {
    if (!isConfigured) {
      return unavailableMessage;
    }

    const prefix =
        'Provide clear, step-by-step first-aid instructions for the following situation in a gradual and simple manner. '
        'Use easy-to-understand language, avoid complex medical jargon. '
        'Format with markdown: numbered steps, **bold** for warnings, bullet lists where helpful: ';

    try {
      final text = await _postChat(
        messages: [
          {'role': 'user', 'content': '$prefix$query'},
        ],
        maxTokens: 600,
        temperature: 0.5,
      );

      if (text == null) {
        return unavailableMessage;
      }
      return text;
    } on DioException catch (e) {
      return _messageForUser(e);
    } catch (e) {
      debugPrint('OpenAI emergency guidance error: $e');
      return unavailableMessage;
    }
  }
}
