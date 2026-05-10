import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nhap/l10n/app_localizations.dart';

import 'library_book_gate.dart';
import 'pdf_reader_page.dart';
import 'upload_pdf.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Map<String, dynamic>> pdfs = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  final TextEditingController searchController = TextEditingController();

  Set<String> _purchasedBookIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _purchaseSub;
  StreamSubscription<User?>? _authSub;

  late Box archiveBox;
  late Box notesBox;
  late Box achievementsBox;

  int streakDays = 0;
  Map<String, bool> achieved = {};

  @override
  void initState() {
    super.initState();
    _initBoxes();
    _fetchPDFs();
    _listenPurchases();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (mounted) {
          setState(() => _purchasedBookIds = {});
        }
        _purchaseSub?.cancel();
        _purchaseSub = null;
        return;
      }
      _listenPurchases();
    });
  }

  void _listenPurchases() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _purchaseSub?.cancel();
    _purchaseSub = FirebaseFirestore.instance
        .collection('libraryPurchases')
        .where('buyerId', isEqualTo: uid)
        .limit(500)
        .snapshots()
        .listen((snap) {
      final ids = <String>{};
      for (final d in snap.docs) {
        final x = d.data();
        if (x['status'] == 'success' && x['bookId'] is String) {
          ids.add(x['bookId'] as String);
        }
      }
      if (mounted) setState(() => _purchasedBookIds = ids);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _purchaseSub?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _findPdfForLibraryDoc(Map<String, dynamic> partial) {
    final bid =
        partial['bookId']?.toString() ?? partial['id']?.toString() ?? '';
    final url = partial['url']?.toString() ?? '';
    if (bid.isNotEmpty) {
      for (final p in pdfs) {
        if (p['id']?.toString() == bid) return Map<String, dynamic>.from(p);
      }
    }
    if (url.isNotEmpty) {
      for (final p in pdfs) {
        if (p['url']?.toString() == url) return Map<String, dynamic>.from(p);
      }
    }
    return null;
  }

  Map<String, dynamic> _mergeWithLibraryMetadata(Map<String, dynamic> partial) {
    final lib = _findPdfForLibraryDoc(partial);
    if (lib == null) return partial;
    return {...lib, ...partial};
  }

  Future<void> _initBoxes() async {
    archiveBox = Hive.box('reading_archive');
    notesBox = Hive.box('notes_box');
    achievementsBox = Hive.box('achievements_box');

    streakDays = (achievementsBox.get('streakDays') as int?) ?? 0;
    achieved = Map<String, bool>.from(achievementsBox.get('badges') ?? {});
    setState(() {});
  }

  Future<void> _fetchPDFs() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('library')
        .orderBy('timestamp', descending: true)
        .get();
    pdfs = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    filtered = pdfs;
    setState(() => loading = false);
  }

  Future<bool> _isLawyer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return false;
    return userDoc.data()?['Role'] == true;
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Access Denied',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Only Lawyers can upload books to the library.',
          style: TextStyle(color: Colors.grey),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _search(String q) {
    q = q.toLowerCase();
    setState(() {
      filtered = pdfs.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final author = (p['author'] ?? '').toString().toLowerCase();
        final cat = (p['category'] ?? '').toString().toLowerCase();
        return title.contains(q) || author.contains(q) || cat.contains(q);
      }).toList();
    });
  }

  List<Map<String, dynamic>> get continueList {
    final items =
        archiveBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
    items.sort((a, b) {
      final at = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
      final bt = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
      return bt.compareTo(at);
    });
    return items;
  }

  Future<void> _openReader(Map<String, dynamic> pdf,
      {bool fromNote = false, int? page}) async {
    final merged = _mergeWithLibraryMetadata(pdf);
    if (!libraryBookCanAccess(merged, _purchasedBookIds)) {
      final ok = await promptLibraryBookPurchase(
        context,
        merged,
        onBookPurchased: (id) {
          if (mounted) {
            setState(() => _purchasedBookIds = {..._purchasedBookIds, id});
          }
        },
      );
      if (!ok) return;
    }
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PDFReaderPage(
                  title: merged['title'] ?? 'Untitled',
                  url: merged['url'] ?? '',
                  id: merged['id'] ?? merged['title'],
                  fromNote: fromNote,
                  initialPage: page,
                )));
    if (mounted) setState(() {});
  }

  Widget _bookCard(Map<String, dynamic> pdf) {
    final price = (pdf['price'] as num?)?.toDouble() ?? 0.0;
    final id = pdf['id'] ?? pdf['title'];
    final saved = archiveBox.get(id);
    final progress =
        saved != null ? (saved['progress'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final locked = price > 0 && !libraryBookCanAccess(pdf, _purchasedBookIds);

    return GestureDetector(
      onTap: () => _openReader(pdf),
      child: Hero(
        tag: 'book_$id',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey[800]!,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf,
                            color: Colors.white, size: 28),
                      ),
                      if (locked)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock,
                                color: Colors.amber, size: 14),
                          ),
                        ),
                    ],
                  ),
                  if (progress > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                pdf['title'] ??
                    (AppLocalizations.of(context)?.untitled ?? 'Untitled'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                pdf['author'] ??
                    (AppLocalizations.of(context)?.unknown ?? 'Unknown'),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (progress > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[850],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 4,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (price > 0)
                    Text(
                      '₵${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    )
                  else
                    Text(
                      AppLocalizations.of(context)?.free ?? 'Free',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      if (archiveBox.containsKey(id)) {
                        archiveBox.delete(id);
                      } else {
                        archiveBox.put(id, {
                          'id': id,
                          'bookId': pdf['id'],
                          'url': pdf['url'],
                          'title': pdf['title'] ?? 'Untitled',
                          'progress': progress,
                          'progressPage': saved?['progressPage'] ?? 1,
                          'timestamp': DateTime.now().toIso8601String()
                        });
                      }
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: archiveBox.containsKey(id)
                            ? Colors.white
                            : Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        archiveBox.containsKey(id)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: archiveBox.containsKey(id)
                            ? Colors.black
                            : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _continueStrip() {
    final cont = continueList;
    if (cont.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cont.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = cont[i];
          final progress = (it['progress'] as num?)?.toDouble() ?? 0.0;
          return GestureDetector(
            onTap: () {
              final merged = _mergeWithLibraryMetadata(
                  Map<String, dynamic>.from(it));
              _openReader(merged, page: it['progressPage'] as int?);
            },
            child: Container(
              width: 240,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[800]!),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          it['title'] ?? 'Untitled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[850],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% ${AppLocalizations.of(context)?.complete ?? 'complete'}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.black, size: 24),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey[800]!,
                ),
              ),
              child: const Icon(
                Icons.menu_book,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)?.lawInsights ?? 'Law Insights',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            onPressed: () async {
              final isLawyer = await _isLawyer();
              if (!isLawyer) {
                _showAccessDeniedDialog();
                return;
              }
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UploadPDFPage()));
              await _fetchPDFs();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notes, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.grey[900],
                builder: (_) => _notesModal(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatChip(
                              AppLocalizations.of(context)
                                      ?.books(pdfs.length.toString()) ??
                                  '${pdfs.length} Books',
                              Icons.library_books),
                          _buildStatChip(
                              AppLocalizations.of(context)
                                      ?.streak(streakDays.toString()) ??
                                  'Streak ${streakDays}d',
                              Icons.local_fire_department),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        onChanged: _search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              AppLocalizations.of(context)?.searchDocuments ??
                                  'Search title, author, category...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[900],
                          prefixIcon:
                              Icon(Icons.search, color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[800]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[800]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                if (continueList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.continueReading ??
                              'Continue Reading',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)
                                  ?.items(continueList.length.toString()) ??
                              '${continueList.length} items',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _continueStrip(),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.allDocuments ??
                            'All Documents',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)
                                ?.items(filtered.length.toString()) ??
                            '${filtered.length} items',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.7),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _bookCard(filtered[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesModal() {
    final keys = notesBox.keys.toList().reversed.toList();
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[850]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.myNotes ?? 'My Notes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)?.notes(keys.length.toString()) ??
                      '${keys.length} notes',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: keys.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_outlined,
                            color: Colors.grey[700], size: 48),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)?.noNotesYet ??
                              'No notes yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, idx) {
                      final k = keys[idx];
                      final note = notesBox.get(k);
                      return InkWell(
                        onTap: () {
                          final noteMap =
                              Map<String, dynamic>.from(note as Map);
                          final merged =
                              _mergeWithLibraryMetadata(noteMap);
                          _openReader(merged,
                              fromNote: true,
                              page: note['page'] as int?);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[800]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.sticky_note_2,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note['title'] ??
                                          (AppLocalizations.of(context)
                                                  ?.untitled ??
                                              'Untitled'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      note['text'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)?.page(
                                                (note['page'] ?? 0)
                                                    .toString()) ??
                                            'Page ${note['page'] ?? 0}',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: keys.length,
                  ),
          ),
        ],
      ),
    );
  }
}
