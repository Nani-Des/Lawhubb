import 'package:nhap/utils/country_utils.dart';

/// Ghana local areas — stored as `Region` on Users.
const List<String> kGhanaRegionOptions = [
  'Western North',
  'Western',
  'Oti',
  'Bono',
  'Bono East',
  'Ahafo',
  'Greater Accra',
  'Eastern',
  'Central',
  'Northern',
  'Savannah',
  'North East',
  'Volta',
  'Upper East',
  'Upper West',
  'Ashanti',
];

bool isGhanaCountry(String? code) {
  final c = (code ?? kDefaultCountryCode).trim().toUpperCase();
  return c == 'GH';
}

String regionFieldLabel(String? countryCode) {
  return isGhanaCountry(countryCode)
      ? 'Region (Ghana)'
      : 'State / province / region';
}

bool isValidRegionForCountry(String? countryCode, String? region) {
  final r = region?.trim() ?? '';
  if (r.isEmpty || r == 'Select a region') return false;
  if (isGhanaCountry(countryCode)) {
    return kGhanaRegionOptions.contains(r);
  }
  return r.length >= 2;
}
