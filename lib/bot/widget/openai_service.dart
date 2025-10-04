import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _baseUrl = "https://api.openai.com/v1/chat/completions";
  static const String _apiKey = "";

  static Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {"role": "system", "content": "You are LawHub Assistant, a legal guide for users in Ghana. Always provide clear, accurate and safe guidance without giving definitive legal advice."},
            {"role": "user", "content": message}
          ],
          "max_tokens": 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["choices"][0]["message"]["content"].trim();
      } else {
        return "⚠️ Sorry, I couldn’t process your request right now.";
      }
    } catch (e) {
      return "⚠️ Something went wrong. Please try again later.";
    }
  }
}
