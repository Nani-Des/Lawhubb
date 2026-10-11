/// Shared bookshop taxonomy — used for lawyer uploads and user search.
const List<String> kLibraryCategories = [
  'All',
  'Criminal Law',
  'Civil Law',
  'Corporate / Commercial Law',
  'Constitutional Law',
  'Family Law',
  'Property / Land Law',
  'Employment / Labour Law',
  'Tax Law',
  'Intellectual Property',
  'Human Rights',
  'International Law',
  'Practice Manuals',
  'Case Digests',
  'Statutes / Acts',
  'Legal Ethics',
  'Other',
];

const List<String> kLibraryFileTypes = ['All', 'PDF', 'DOC', 'DOCX'];

String libraryCategoryOrOther(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return 'Other';
  if (kLibraryCategories.contains(v)) return v;
  return v;
}

/// Categories lawyers can pick when uploading (excludes "All").
List<String> get kLibraryUploadCategories =>
    kLibraryCategories.where((c) => c != 'All').toList();

/// Platform fee retained from book sales (10%).
const double kLibraryPlatformFeeRate = 0.10;
