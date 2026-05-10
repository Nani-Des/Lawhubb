import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

import 'paystack_inline_checkout_page.dart';
import 'pdf_reader_page.dart';

/// Mirrors LawhubbAdminPanel `DoctorLibraryPage` access rules.
bool libraryBookCanAccess(
    Map<String, dynamic> pdf, Set<String> purchasedBookIds) {
  final price = (pdf['price'] as num?)?.toDouble() ?? 0.0;
  if (price <= 0) return true;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final owner = (pdf['uploadedBy'] ?? pdf['sellerId'])?.toString();
  if (owner == uid) return true;
  final id = pdf['id']?.toString() ?? '';
  if (id.isEmpty) return false;
  return purchasedBookIds.contains(id);
}

Future<Set<String>> fetchPurchasedBookIdsForCurrentUser() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return {};
  final snap = await FirebaseFirestore.instance
      .collection('libraryPurchases')
      .where('buyerId', isEqualTo: uid)
      .limit(500)
      .get();
  final ids = <String>{};
  for (final d in snap.docs) {
    final x = d.data();
    if (x['status'] == 'success' && x['bookId'] is String) {
      ids.add(x['bookId'] as String);
    }
  }
  return ids;
}

/// Fills in [price], [uploadedBy], etc. when only archive / note fields exist.
Future<Map<String, dynamic>> resolveLibraryBookFromFirestore(
  Map<String, dynamic> partial,
) async {
  final bid = partial['bookId']?.toString() ?? partial['id']?.toString() ?? '';
  final url = partial['url']?.toString() ?? '';
  if (bid.isNotEmpty) {
    final doc =
        await FirebaseFirestore.instance.collection('library').doc(bid).get();
    if (doc.exists && doc.data() != null) {
      return {...doc.data()!, 'id': doc.id, ...partial};
    }
  }
  if (url.isNotEmpty) {
    final qs = await FirebaseFirestore.instance
        .collection('library')
        .where('url', isEqualTo: url)
        .limit(1)
        .get();
    if (qs.docs.isNotEmpty) {
      final d = qs.docs.first;
      return {...d.data(), 'id': d.id, ...partial};
    }
  }
  return partial;
}

Future<void> recordLibraryPurchase(
  Map<String, dynamic> pdf,
  String paystackReference,
  double amount,
  User user, {
  void Function(String bookId)? onBookPurchased,
}) async {
  await FirebaseFirestore.instance.collection('libraryPurchases').add({
    'bookId': pdf['id'],
    'bookTitle': pdf['title'] ?? '',
    'amount': amount,
    'buyerId': user.uid,
    'buyerEmail': user.email ?? '${user.uid}@lawhubb.local',
    'sellerId': (pdf['uploadedBy'] ?? pdf['sellerId'] ?? '').toString(),
    'paystackReference': paystackReference,
    'provider': 'paystack',
    'status': 'success',
    'isPaid': true,
    'paymentStatus': 'paid',
    'createdAt': FieldValue.serverTimestamp(),
    'payoutNumber': '+233558466487',
  });
  final bid = pdf['id']?.toString();
  if (bid != null) onBookPurchased?.call(bid);
}

/// Returns true if the user may open the book (paid, free, or already owned).
Future<bool> promptLibraryBookPurchase(
  BuildContext context,
  Map<String, dynamic> pdf, {
  void Function(String bookId)? onBookPurchased,
}) async {
  final price = (pdf['price'] as num?)?.toDouble() ?? 0.0;
  if (price <= 0) return true;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to purchase books.')),
    );
    return false;
  }
  final email = user.email?.trim();
  if (email == null || email.isEmpty || !email.contains('@')) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add an email address to your account in profile settings to pay with Paystack.',
        ),
      ),
    );
    return false;
  }
  final rc = FirebaseRemoteConfig.instance;
  await rc.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(seconds: 60),
  ));
  await rc.setDefaults(const {'paystack_public_key': ''});
  await rc.fetchAndActivate();
  final pk = rc.getString('paystack_public_key').trim();
  if (pk.isEmpty) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Payments are not configured. Try again later.')),
    );
    return false;
  }
  if (!context.mounted) return false;
  final reference = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => PaystackInlineCheckoutPage(
        publicKey: pk,
        email: email,
        amountGhs: price,
        bookTitle: (pdf['title'] ?? 'Book').toString(),
      ),
    ),
  );
  if (reference == null || reference.isEmpty) return false;
  await recordLibraryPurchase(
    pdf,
    reference,
    price,
    user,
    onBookPurchased: onBookPurchased,
  );
  return true;
}

/// Opens [PDFReaderPage] after resolving Firestore metadata and enforcing paywall.
Future<void> openLibraryBookReader(
  BuildContext context,
  Map<String, dynamic> partial, {
  int? initialPage,
  bool fromNote = false,
}) async {
  final merged = await resolveLibraryBookFromFirestore(partial);
  var purchased = await fetchPurchasedBookIdsForCurrentUser();
  if (!libraryBookCanAccess(merged, purchased)) {
    final ok = await promptLibraryBookPurchase(context, merged);
    if (!ok) return;
    purchased = await fetchPurchasedBookIdsForCurrentUser();
    if (!libraryBookCanAccess(merged, purchased)) return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PDFReaderPage(
        title: merged['title'] ?? 'Untitled',
        url: merged['url'] ?? '',
        id: merged['id'] ?? merged['title'],
        fromNote: fromNote,
        initialPage: initialPage,
      ),
    ),
  );
}
