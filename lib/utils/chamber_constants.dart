import 'package:cloud_firestore/cloud_firestore.dart';

/// Placeholder chamber for applicants who type a custom chamber name.
const String kNaChamberName = 'Chamber [N/A]';

String? _cachedNaChamberId;

/// Resolves the Firestore document id for [kNaChamberName].
Future<String?> resolveNaChamberId(FirebaseFirestore db) async {
  if (_cachedNaChamberId != null) return _cachedNaChamberId;

  final byName = await db
      .collection('Chamber')
      .where('Chamber Name', isEqualTo: kNaChamberName)
      .limit(1)
      .get();
  if (byName.docs.isNotEmpty) {
    _cachedNaChamberId = byName.docs.first.id;
    return _cachedNaChamberId;
  }

  const fallbackId = 'chamber_na';
  final fallback = await db.collection('Chamber').doc(fallbackId).get();
  if (fallback.exists) {
    _cachedNaChamberId = fallbackId;
    return _cachedNaChamberId;
  }

  return null;
}
