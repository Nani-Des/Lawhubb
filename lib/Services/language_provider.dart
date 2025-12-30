import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageBoxKey = 'language_settings';
  static const String _selectedLanguageKey = 'selected_language';

  late Box<String> _languageBox;
  Locale _currentLocale = const Locale('en');
  bool _isInitialized = false;

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;
  bool get isInitialized => _isInitialized;

  /// Initialize the language provider and load saved language preference
  Future<void> init() async {
    try {
      _languageBox = await Hive.openBox<String>(_languageBoxKey);

      // Get saved language or default to English
      final savedLanguage = _languageBox.get(
        _selectedLanguageKey,
        defaultValue: 'en',
      );

      _currentLocale = Locale(savedLanguage!);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing LanguageProvider: $e');
      _currentLocale = const Locale('en');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Change the application language and persist the selection
  Future<void> changeLanguage(String languageCode) async {
    if (languageCode == _currentLocale.languageCode) {
      return; // No need to change if it's the same language
    }

    try {
      _currentLocale = Locale(languageCode);

      // Save the language preference to Hive
      await _languageBox.put(_selectedLanguageKey, languageCode);

      notifyListeners();
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }

  /// Get the flag emoji for a language code
  String getFlagEmoji(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸'; // US flag for English
      case 'es':
        return '🇪🇸'; // Spain flag for Spanish
      case 'fr':
        return '🇫🇷'; // France flag for French
      default:
        return '🇺🇸';
    }
  }
}
