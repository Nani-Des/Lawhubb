import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static const String _baseUrl = "https://api.openai.com/v1/chat/completions";

  static Future<String> sendMessage(String message) async {
    try {
      final String apiKey = dotenv.env['OPENAI_API_KEY1'] ?? '';
      final String projectId = dotenv.env['OPENAI_PROJECT_ID'] ?? '';

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
      print("❌ DioError: ${dioError.response?.data ?? dioError.message}");
      return "⚠️ Failed: ${dioError.response?.data?['error']?['message'] ?? 'Unknown Dio error'}";
    } catch (e) {
      print("❌ Exception: $e");
      return "⚠️ Something went wrong: $e";
    }
  }
}
