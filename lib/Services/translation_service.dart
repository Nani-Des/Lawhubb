import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class TranslationService {
  static final Map<String, String> _cache = <String, String>{};

  // Language codes for static translation menus
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

  /// Extended set used in community modules.
  static const Map<String, String> ghanaianLanguages = {
    'en': 'English',
    'tw': 'Twi',
    'ee': 'Ewe',
    'gaa': 'Ga',
    'fat': 'Fante',
    'yo': 'Yoruba',
    'dag': 'Dagbani',
    'ki': 'Kikuyu',
    'gur': 'Gurune',
    'luo': 'Luo',
    'mer': 'Kimeru',
    'kus': 'Kusaal',
  };

  /// Translate text using Google Translate API
  /// Returns translated text or original text if translation fails
  static Future<String> translateText(
    String text,
    String targetLanguageCode, {
    String sourceLanguage = 'auto',
  }) async {
    if (text.isEmpty) {
      return text;
    }
    if (targetLanguageCode.isEmpty || targetLanguageCode == sourceLanguage) {
      return text;
    }

    final cacheKey = '$sourceLanguage|$targetLanguageCode|$text';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      // Using google translate free API endpoint
      final String url =
          'https://translate.google.com/translate_a/single?client=gtx&sl=$sourceLanguage&tl=$targetLanguageCode&dt=t&q=${Uri.encodeComponent(text)}';

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

          final translated = translatedText.toString();
          _cache[cacheKey] = translated;
          return translated;
        }
      }

      // Return original text if translation fails
      _cache[cacheKey] = text;
      return text;
    } catch (e) {
      print('Translation error: $e');
      // Return original text on error
      _cache[cacheKey] = text;
      return text;
    }
  }

  /// Translate text to currently selected app locale.
  static Future<String> translateForContext(
    BuildContext context,
    String text,
  ) async {
    final targetCode = Localizations.localeOf(context).languageCode;
    if (targetCode == 'en') return text;
    return translateText(text, targetCode);
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
