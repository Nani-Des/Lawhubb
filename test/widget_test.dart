import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nhap/Services/language_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('LanguageProvider initializes with default English locale', () async {
    final languageProvider = LanguageProvider();
    await languageProvider.init();

    expect(languageProvider.isInitialized, isTrue);
    expect(languageProvider.currentLanguageCode, 'en');
  });

  test('LanguageProvider persists language change', () async {
    final languageProvider = LanguageProvider();
    await languageProvider.init();
    await languageProvider.changeLanguage('fr');

    expect(languageProvider.currentLanguageCode, 'fr');
  });
}
