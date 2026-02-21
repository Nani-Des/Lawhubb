import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslationService {
  static const String _googleTranslateApiUrl =
      'https://translate.googleapis.com/translate_a/element.js?cb=googleTranslateElementInit';

  // Language codes for translation
  static const Map<String, String> languageCodes = {
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
  };

  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
  };

  /// Translate text using Google Translate API
  /// Returns translated text or original text if translation fails
  static Future<String> translateText(
    String text,
    String targetLanguageCode,
  ) async {
    if (text.isEmpty) {
      return text;
    }

    try {
      // Using google translate free API endpoint
      final String url =
          'https://translate.google.com/translate_a/single?client=gtx&sl=auto&tl=$targetLanguageCode&dt=t&q=${Uri.encodeComponent(text)}';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Translation request timeout'),
          );

      if (response.statusCode == 200) {
        // Parse the response
        final List<dynamic> jsonResponse = jsonDecode(response.body);

        // Extract translated text
        if (jsonResponse.isNotEmpty && jsonResponse[0] is List) {
          StringBuffer translatedText = StringBuffer();

          // Concatenate all translated segments
          for (var segment in jsonResponse[0]) {
            if (segment is List && segment.isNotEmpty) {
              translatedText.write(segment[0]);
            }
          }

          return translatedText.toString();
        }
      }

      // Return original text if translation fails
      return text;
    } catch (e) {
      print('Translation error: $e');
      // Return original text on error
      return text;
    }
  }

  /// Translate multiple texts
  static Future<Map<String, String>> translateTexts(
    Map<String, String> textsToTranslate,
    String targetLanguageCode,
  ) async {
    final translatedTexts = <String, String>{};

    for (var entry in textsToTranslate.entries) {
      final translatedText =
          await translateText(entry.value, targetLanguageCode);
      translatedTexts[entry.key] = translatedText;
    }

    return translatedTexts;
  }

  /// Get language code from language name
  static String getLanguageCode(String languageName) {
    return languageCodes[languageName] ?? 'en';
  }

  /// Get language name from language code
  static String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? 'Unknown';
  }
}
