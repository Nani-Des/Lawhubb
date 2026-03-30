import 'dart:convert'                                              ;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../Services/config_service.dart';

class OpenAIService {
  static const String _baseUrl = "https://api.openai.com/v1/chat/completions";


  static Future<String> sendMessage(String message) async {
    try {
      final config = ConfigService();
      final String apiKey = config.openAiApiKey1;
      final String projectId = config.openAiProjectId;

      if (apiKey.isEmpty || projectId.isEmpty) {
        return "⚠️ API key or Project ID is missing. Please check your .env file.";
      }

      final response = await Dio().post(
        _baseUrl,
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'OpenAI-Project': projectId,  // ✅ Must be your proj_... ID
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
              'You are LawHub Assistant, a legal guide for users in Ghana. Always provide clear, accurate and safe guidance without giving definitive legal advice.'
            },
            {'role': 'user', 'content': message}
          ],
          'max_tokens': 200,
        },
      );

      return response.data['choices'][0]['message']['content'];
    } on DioError catch (dioError) {
      final statusCode = dioError.response?.statusCode;
      if (statusCode == 429) {
        return "⚠️ The assistant is currently busy. Please wait a moment and try again.";
      } else if (statusCode == 401 || statusCode == 403) {
        return "⚠️ The assistant is temporarily unavailable. Please try again later.";
      }
      return "⚠️ Could not reach the assistant. Check your connection and try again.";
    } catch (e) {
      return "⚠️ Something went wrong. Please try again.";
    }
  }
}
