import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class PDFReaderPage extends StatefulWidget {
  final String id;
  final String title;
  final String url;
  final int? initialPage; // jump to note page
  final bool fromNote; // prevent adding to archive

  const PDFReaderPage({
    required this.id,
    required this.title,
    required this.url,
    this.initialPage,
    this.fromNote = false,
    super.key,
  });

  @override
  State<PDFReaderPage> createState() => _PDFReaderPageState();
}

class _PDFReaderPageState extends State<PDFReaderPage> {
  late PdfViewerController _controller;
  int totalPages = 0;
  int currentPage = 1;
  double progress = 0.0;
  bool loading = true;
  bool error = false;
  String? localPath;

  late Box archiveBox;
  late Box notesBox;
  late Box achievementsBox;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    archiveBox = Hive.box('reading_archive');
    notesBox = Hive.box('notes_box');
    achievementsBox = Hive.box('achievements_box');
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() => loading = true);
    await _loadCachedPDF();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  Future<void> _loadCachedPDF() async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = widget.id.replaceAll(RegExp(r'[^\w\-]'), '_') + '.pdf';
    final filePath = File('${dir.path}/$filename');

    if (await filePath.exists()) {
      localPath = filePath.path;
      setState(() => loading = false);
      return;
    }

    try {
      final dio = Dio();
      await dio.download(widget.url, filePath.path, options: Options(receiveTimeout: Duration.zero));
      localPath = filePath.path;
      setState(() {
        loading = false;
        error = false;
      });
    } catch (_) {
      setState(() {
        loading = false;
        error = true;
      });
    }
  }

  void _restorePosition() {
    if (widget.initialPage != null) {
      _controller.jumpToPage(widget.initialPage!);
      return;
    }

    final saved = archiveBox.get(widget.id);
    if (saved != null && saved['progressPage'] != null) {
      _controller.jumpToPage(saved['progressPage'] as int);
    }
  }

  void _saveProgress(int pageNumber) {
    if (totalPages == 0 || widget.fromNote) return;

    final prog = pageNumber / totalPages;
    progress = prog;

    archiveBox.put(widget.id, {
      'url': widget.url,
      'title': widget.title,
      'progress': prog,
      'progressPage': pageNumber,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _updateAchievementsOnProgress(pageNumber);
  }

  void _updateAchievementsOnProgress(int pageNumber) {
    final readPagesKey = '${widget.id}_readPages';
    final readPages = (achievementsBox.get(readPagesKey) as List?)?.cast<int>() ?? [];

    if (!readPages.contains(pageNumber)) readPages.add(pageNumber);
    achievementsBox.put(readPagesKey, readPages);

    if (readPages.length >= 10) {
      achievementsBox.put('badges', {
        ...(achievementsBox.get('badges') ?? {}),
        'deep_diver': true,
      });
    }

    final lastDayKey = 'last_day';
    final lastDay = achievementsBox.get(lastDayKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDay != today) {
      final streakDays = (achievementsBox.get('streakDays') as int?) ?? 0;
      achievementsBox.put('streakDays', streakDays + 1);
      achievementsBox.put(lastDayKey, today);
    }
  }

  Future<void> _addNoteDialog() async {
    final page = currentPage;
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Add Note - Page $page', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Short title',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Your note or highlight',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, minimumSize: const Size.fromHeight(45)),
                onPressed: () {
                  final key = '${widget.id}_${DateTime.now().millisecondsSinceEpoch}';
                  notesBox.put(key, {
                    'title': titleCtrl.text.isEmpty ? 'Note ${DateTime.now()}' : titleCtrl.text,
                    'text': textCtrl.text,
                    'page': page,
                    'timestamp': DateTime.now().toIso8601String(),
                    'bookId': widget.id,
                    'url': widget.url,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ]),
          ),
        );
      },
    );
    setState(() {});
  }

  void _goToLastPage() {
    final saved = archiveBox.get(widget.id);
    if (saved != null && saved['progressPage'] != null) {
      _controller.jumpToPage(saved['progressPage'] as int);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumed to last read page')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.note_add, color: Colors.white), tooltip: 'Add Note', onPressed: _addNoteDialog),
          IconButton(icon: const Icon(Icons.bookmark, color: Colors.white), tooltip: 'Go to Last Page', onPressed: _goToLastPage),
        ],
      ),
      body: error
          ? Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          const Text('Download failed', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _prepare, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Retry'))
        ]),
      )
          : loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Stack(children: [
        SfPdfViewer.file(
          File(localPath!),
          controller: _controller,
          onDocumentLoaded: (details) {
            setState(() => totalPages = details.document.pages.count);
            if (widget.initialPage != null) _controller.jumpToPage(widget.initialPage!);
          },
          onPageChanged: (details) {
            currentPage = details.newPageNumber;
            if (totalPages > 0) _saveProgress(currentPage);
            setState(() {});
          },
        ),
        if (totalPages > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              height: 8,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
              child: FractionallySizedBox(
                widthFactor: currentPage / totalPages,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.redAccent, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 6)]),
                ),
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 50,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
            child: Text('$currentPage / $totalPages', style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.note_alt_outlined, color: Colors.white),
        onPressed: _addNoteDialog,
      ),
    );
  }
}
