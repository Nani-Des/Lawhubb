import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'upload_pdf.dart';
import 'pdf_reader_page.dart';
import 'dart:math' as math;

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
    final snapshot = await FirebaseFirestore.instance.collection('library').orderBy('timestamp', descending: true).get();
    pdfs = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    filtered = pdfs;
    setState(() => loading = false);
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
    final items = archiveBox.values.map((e) => Map<String,dynamic>.from(e)).toList();
    items.sort((a,b) {
      final at = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
      final bt = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
      return bt.compareTo(at);
    });
    return items;
  }

  void _openReader(Map<String,dynamic> pdf, {bool fromNote = false, int? page}) async {
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PDFReaderPage(
          title: pdf['title'] ?? 'Untitled',
          url: pdf['url'] ?? '',
          id: pdf['id'] ?? pdf['title'],
          fromNote: fromNote,
          initialPage: page,
        )
    ));
    setState(() {});
  }

  Widget _bookCard(Map<String,dynamic> pdf) {
    final price = (pdf['price'] as num?)?.toDouble() ?? 0.0;
    final id = pdf['id'] ?? pdf['title'];
    final saved = archiveBox.get(id);
    final progress = saved != null ? (saved['progress'] as num?)?.toDouble() ?? 0.0 : 0.0;

    return GestureDetector(
      onTap: () => _openReader(pdf),
      child: Hero(
        tag: 'book_$id',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 6, offset: const Offset(0,4)),
              if (progress > 0) BoxShadow(color: Colors.redAccent.withOpacity(0.08), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ProgressRing(progress: progress),
                  const SizedBox(width: 8),
                  const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
                ],
              ),
              const SizedBox(height: 10),
              Text(pdf['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(pdf['author'] ?? 'Unknown', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₵${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(archiveBox.containsKey(id) ? Icons.bookmark : Icons.bookmark_add, color: archiveBox.containsKey(id) ? Colors.redAccent : Colors.white70),
                    onPressed: () {
                      if (archiveBox.containsKey(id)) archiveBox.delete(id);
                      else archiveBox.put(id, {
                        'url': pdf['url'],
                        'title': pdf['title'] ?? 'Untitled',
                        'progress': progress,
                        'progressPage': saved?['progressPage'] ?? 1,
                        'timestamp': DateTime.now().toIso8601String()
                      });
                      setState(() {});
                    },
                  )
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
      height: 86,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: cont.length,
        separatorBuilder: (_,__) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = cont[i];
          return GestureDetector(
            onTap: () => _openReader(it, page: it['progressPage']),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('${(it['progress']*100).toStringAsFixed(0)}% read', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 28),
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
        backgroundColor: Colors.redAccent,
        elevation: 0,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('Library', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _buildBadge('Streak ${streakDays}d', Icons.whatshot, active: streakDays >= 3),
              _buildBadge('Deep Diver', Icons.psychology, active: achieved['deep_diver'] ?? false),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file, color: Colors.white), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPDFPage()));
            await _fetchPDFs();
          }),
          IconButton(icon: const Icon(Icons.notes, color: Colors.white), onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.grey[900],
              builder: (_) => _notesModal(),
            );
          }),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              onChanged: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search title/author/category',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          _continueStrip(),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _bookCard(filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, {bool active = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: active ? Colors.redAccent : Colors.grey[850], borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _notesModal() {
    final keys = notesBox.keys.toList().reversed.toList();
    return Container(
      height: 420,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Notes', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: keys.isEmpty
                ? const Center(child: Text('No notes yet', style: TextStyle(color: Colors.white70)))
                : ListView.separated(
              itemBuilder: (ctx, idx) {
                final k = keys[idx];
                final note = notesBox.get(k);
                return InkWell(
                  onTap: () => _openReader(note, fromNote: true, page: note['page']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note['title'] ?? k, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(note['text'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('Page ${note['page'] ?? 0}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: keys.length,
            ),
          ),
        ],
      ),
    );
  }
}

// Tiny progress ring
class _ProgressRing extends StatelessWidget {
  final double progress;
  const _ProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
          Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}
