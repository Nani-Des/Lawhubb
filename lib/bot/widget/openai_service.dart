import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../Services/config_service.dart';

/// OpenAI calls for LawHub Assistant + find-lawyer classification.
class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static String _apiKey(ConfigService config) {
    final k = config.openAiApiKey1.trim();
    if (k.isNotEmpty) return k;
    return (dotenv.env['OPENAI_API_KEY1'] ?? dotenv.env['OPENAI_API_KEY'] ?? '')
        .trim();
  }

  static String _projectId(ConfigService config) {
    final p = config.openAiProjectId.trim();
    if (p.isNotEmpty) return p;
    return (dotenv.env['OPENAI_PROJECT_ID'] ?? '').trim();
  }

  static Map<String, String> _headers(ConfigService config) {
    final apiKey = _apiKey(config);
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final proj = _projectId(config);
    if (proj.isNotEmpty) {
      headers['OpenAI-Project'] = proj;
    }
    return headers;
  }

  /// Never surface raw API/provider messages to end users.
  static String _friendlyChatAssistantMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Unable to reach the assistant. Check your internet connection and try again.';
      case DioExceptionType.cancel:
        return 'The request was interrupted. Please try again.';
      case DioExceptionType.badCertificate:
        return 'A secure connection couldn’t be established. Please try again later.';
      case DioExceptionType.unknown:
        if (e.message != null &&
            e.message!.toLowerCase().contains('socket')) {
          return 'Unable to reach the assistant. Check your internet connection and try again.';
        }
        break;
      default:
        break;
    }

    final status = e.response?.statusCode;
    if (status == 429) {
      return 'The assistant is busy right now. Please wait a moment and try again.';
    }
    if (status == 503 || status == 502 || status == 504) {
      return 'The assistant is temporarily unavailable. Please try again in a few minutes.';
    }
    if (status == 401 || status == 403) {
      return 'LawHub Assistant isn’t available right now. Please try again later.';
    }

    return 'LawHub Assistant couldn’t complete that. Please try again.';
  }

  /// Chat replies for LawHub Assistant (longer output).
  static Future<String> sendMessage(String message) async {
    final config = ConfigService();
    final apiKey = _apiKey(config);
    if (apiKey.isEmpty) {
      return 'LawHub Assistant isn’t available right now. Please try again later.';
    }

    try {
      final response = await Dio().post(
        _baseUrl,
        options: Options(headers: _headers(config)),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are LawHub Assistant for LawHubb. You help users in Ghana understand legal topics in plain language. '
                  'Be concise, structured, and practical. Do not claim to be a lawyer or give guaranteed outcomes. '
                  'When unsure, suggest consulting a qualified lawyer through the app.',
            },
            {'role': 'user', 'content': message},
          ],
          'max_tokens': 600,
          'temperature': 0.55,
        },
      );

      final data = response.data;
      if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
        final choice = data['choices'][0];
        if (choice is Map && choice['message'] is Map) {
          final content = choice['message']['content'];
          if (content != null) return content.toString().trim();
        }
      }
      return 'Could not read the assistant response. Please try again.';
    } on DioException catch (e) {
      debugPrint('OpenAI DioException: ${e.response?.data ?? e.message}');
      return _friendlyChatAssistantMessage(e);
    } catch (e, st) {
      debugPrint('OpenAI error: $e\n$st');
      return 'Something went wrong. Please try again.';
    }
  }

  /// Short classification output for practice matching (find lawyer).
  static Future<String> classifyPractice({
    required String userQuery,
    required List<String> practiceNames,
  }) async {
    final config = ConfigService();
    final apiKey = _apiKey(config);
    if (apiKey.isEmpty) {
      return '';
    }

    final list = practiceNames.join(', ');
    final prompt =
        'You must choose exactly ONE practice name from this list that best matches the user issue. '
        'Reply with ONLY that practice name, nothing else — no quotes, no punctuation, no explanation.\n'
        'List: $list\n'
        'User issue: $userQuery';

    try {
      final response = await Dio().post(
        _baseUrl,
        options: Options(headers: _headers(config)),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You map user legal questions to one practice label from a fixed list. Output only the label.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 40,
          'temperature': 0.1,
        },
      );

      final data = response.data;
      if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
        final choice = data['choices'][0];
        if (choice is Map && choice['message'] is Map) {
          final content = choice['message']['content'];
          if (content != null) return content.toString().trim();
        }
      }
      return '';
    } on DioException catch (e) {
      debugPrint('OpenAI classifyPractice: ${e.response?.data ?? e.message}');
      return '';
    } catch (e) {
      debugPrint('OpenAI classifyPractice error: $e');
      return '';
    }
  }
}
