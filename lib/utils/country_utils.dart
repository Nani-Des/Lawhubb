import 'package:nhap/data/iso3166_country_choices.dart';

export 'package:nhap/data/iso3166_country_choices.dart' show kIso3166CountryChoices;

/// ISO 3166-1 alpha-2 list sorted by name (UN/ISO dataset).
const List<Map<String, String>> kCountryChoices = kIso3166CountryChoices;

/// ISO 3166-1 alpha-2. Legacy Firestore users without [Country] are treated as Ghana.
const String kDefaultCountryCode = 'GH';

String effectiveCountryCode(Map<String, dynamic>? data) {
  if (data == null) return kDefaultCountryCode;
  final raw = data['Country'] ?? data['country'];
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim().toUpperCase();
  }
  return kDefaultCountryCode;
}

/// Firestore flag set for brand-new Google sign-ups until the user picks a country.
bool countrySelectionRequired(Map<String, dynamic>? data) {
  if (data == null) return false;
  final v = data['CountryRequired'];
  return v == true;
}

String countryNameFromCode(String code) {
  final u = code.trim().toUpperCase();
  for (final m in kCountryChoices) {
    if (m['code'] == u) return m['name'] ?? u;
  }
  return u;
}
