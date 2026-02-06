import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Production-ready Google Cloud Translation Service
///
/// Setup Instructions:
/// 1. Create a GCP project: https://console.cloud.google.com
/// 2. Enable Cloud Translation API
/// 3. Create an API key: https://console.cloud.google.com/apis/credentials
/// 4. Add your API key to:
///    - Android: android/app/build.gradle as a buildConfigField
///    - iOS: ios/Runner/Info.plist
///    - Web: web/index.html or environment config
/// 5. Store API key securely using flutter_dotenv or Firebase Remote Config
class TranslationService {
  /// API endpoint for Google Cloud Translation API
  static const String _apiEndpoint =
      'https://translation.googleapis.com/language/translate/v2';

  /// Your Google Cloud API Key
  /// IMPORTANT: Store this securely - DO NOT hardcode in production
  ///
  /// Best practice: Use flutter_dotenv with .env file
  /// In main.dart: await dotenv.load();
  /// Then this will read from .env file:
  /// GOOGLE_TRANSLATION_API_KEY=your_key_here
  static String get _apiKey {
    try {
      // Try to get from environment file (development/testing)
      final envKey = dotenv.env['GOOGLE_TRANSLATION_API_KEY'] ?? '';
      if (envKey.isNotEmpty) {
        return envKey;
      }

      // For production, use Firebase Remote Config or secure storage
      throw Exception(
        'Google Translation API key not found. '
        'Configure it using one of these methods:\n'
        '1. Add GOOGLE_TRANSLATION_API_KEY to .env file (development)\n'
        '2. Use Firebase Remote Config (production)\n'
        '3. Use secure storage solution\n\n'
        'See TRANSLATION_API_SETUP.md for detailed instructions.',
      );
    } catch (e) {
      print('API Key Configuration Error: $e');
      rethrow;
    }
  }

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

  /// Translate text using official Google Cloud Translation API
  ///
  /// Parameters:
  ///   - text: The text to translate
  ///   - targetLanguageCode: Target language code (e.g., 'es', 'fr', 'en')
  ///
  /// Returns translated text or original text if translation fails
  static Future<String> translateText(
    String text,
    String targetLanguageCode,
  ) async {
    if (text.isEmpty) {
      return text;
    }

    try {
      // Build request body
      final requestBody = {
        'q': text,
        'target_language_code': targetLanguageCode,
      };

      // Make API request
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint?key=$_apiKey'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Client': 'gax/1.0',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Translation request timeout (15s)'),
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Extract translated text from response
        if (jsonResponse['data'] != null &&
            jsonResponse['data']['translations'] != null &&
            (jsonResponse['data']['translations'] as List).isNotEmpty) {
          final translatedText =
              jsonResponse['data']['translations'][0]['translated_text'];
          return translatedText ?? text;
        }
        // Return original text if response structure is unexpected
        return text;
      } else if (response.statusCode == 400) {
        // Bad request - likely invalid language code
        throw Exception(
            'Invalid language code or text format: ${response.body}');
      } else if (response.statusCode == 403) {
        // Permission denied - likely invalid or missing API key
        throw Exception(
            'Translation API access denied. Check your API key configuration.');
      } else if (response.statusCode == 429) {
        // Rate limited
        throw Exception(
            'Translation API rate limit exceeded. Try again later.');
      } else if (response.statusCode == 500) {
        // Server error
        throw Exception('Google Translation service temporarily unavailable.');
      } else {
        throw Exception(
            'Translation failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Translation error: $e');
      // Return original text on error
      return text;
    }
  }

  /// Translate multiple texts in batch
  /// Note: For large batches, consider using Cloud Translation API batch processing
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

  /// Supported languages list
  static List<String> getSupportedLanguages() {
    return languageCodes.keys.toList();
  }
}
