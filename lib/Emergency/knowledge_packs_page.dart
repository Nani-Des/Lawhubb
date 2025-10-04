import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'Widgets/article_detail_page.dart';

class KnowledgePacksPage extends StatefulWidget {
  @override
  _KnowledgePacksPageState createState() => _KnowledgePacksPageState();
}

class _KnowledgePacksPageState extends State<KnowledgePacksPage> with SingleTickerProviderStateMixin {
  Map<String, List<Map<String, dynamic>>> categorizedArticles = {};
  bool isLoading = true;
  late Box<String> knowledgePackBox;
  late Box<String> archivedArticlesBox;
  late Map<String, List<Map<String, dynamic>>> localArticles;
  bool showArchived = false;

  String searchQuery = "";

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);
  }

  Future<void> _initializeData() async {
    await initializeHive();
    await loadAllArticles();
  }

  Future<void> initializeHive() async {
    knowledgePackBox = await Hive.openBox<String>('knowledge_packs');
    archivedArticlesBox = await Hive.openBox<String>('archived_articles');
  }

  Future<void> loadAllArticles() async {
    setState(() => isLoading = true);
    localArticles = await loadLocalData();
    final remoteData = await fetchRemoteData();

    final combinedData = {...localArticles};
    remoteData.forEach((category, articles) {
      combinedData.putIfAbsent(category, () => []);
      combinedData[category]!.addAll(articles);
    });

    setState(() {
      categorizedArticles = combinedData;
      isLoading = false;
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadLocalData() async {
    final String response = await rootBundle.loadString('assets/knowledge_packs.json');
    final List<dynamic> data = json.decode(response);

    final Map<String, List<Map<String, dynamic>>> categorized = {};
    for (final categoryData in data) {
      final category = categoryData['category'];
      final articles = List<Map<String, dynamic>>.from(categoryData['articles']);
      categorized[category] = articles;
    }
    return categorized;
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchRemoteData() async {
    final snapshot = await FirebaseFirestore.instance.collection('KnowledgePacks').get();
    final Map<String, List<Map<String, dynamic>>> categorized = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data['Category'];
      final articles = List<Map<String, dynamic>>.from(data['articles']);

      categorized.putIfAbsent(category, () => []);
      for (final article in articles) {
        if (article['title'] != null && article['content'] != null) {
          categorized[category]!.add(article);
        }
      }
    }
    return categorized;
  }

  Future<void> saveArticleOffline(String title, String content) async {
    await knowledgePackBox.put(title, content);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Downloaded: $title", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
    );
  }

  Future<String?> getOfflineArticle(String title) async {
    if (knowledgePackBox.containsKey(title)) {
      return knowledgePackBox.get(title);
    }
    for (var category in localArticles.values) {
      for (var article in category) {
        if (article['title'] == title) {
          return article['content'];
        }
      }
    }
    return null;
  }

  Future<void> toggleArchiveArticle(String title, String content) async {
    if (archivedArticlesBox.containsKey(title)) {
      await archivedArticlesBox.delete(title);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unarchived: $title", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await archivedArticlesBox.put(title, content);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Archived: $title", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    setState(() {});
  }

  Map<String, List<Map<String, dynamic>>> getFilteredArticles() {
    final source = showArchived
        ? categorizedArticles.map((key, value) => MapEntry(
      key,
      value.where((a) => archivedArticlesBox.containsKey(a['title'])).toList(),
    ))
        : categorizedArticles;

    if (searchQuery.isEmpty) return source;

    final Map<String, List<Map<String, dynamic>>> filtered = {};
    source.forEach((category, articles) {
      final matches = articles.where((a) => a['title'].toLowerCase().contains(searchQuery.toLowerCase())).toList();
      if (matches.isNotEmpty) filtered[category] = matches;
    });
    return filtered;
  }

  @override
  void dispose() {
    knowledgePackBox.close();
    archivedArticlesBox.close();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.redAccent.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: _buildLoadingState(),
      );
    }

    final filteredArticles = getFilteredArticles();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: true,
        title: Text(
          showArchived ? "Archived Library" : "Knowledge Library",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(showArchived ? Icons.library_books : Icons.archive, color: Colors.white),
            onPressed: () => setState(() => showArchived = !showArchived),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search books...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.black),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredArticles.isEmpty
                ? _buildEmptyState()
                : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: filteredArticles.entries.map((entry) {
                return _buildCategoryShelf(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSophisticatedProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            "Loading Knowledge Packs...",
            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            showArchived ? "No Archived Packs" : "No Books Available",
            style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            showArchived ? "Archive some packs to see them here!" : "Check back later for new content.",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryShelf(String category, List<Map<String, dynamic>> articles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              category,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return _buildArticleCard(articles[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
    return GestureDetector(
      onTap: () async {
        final offlineContent = await getOfflineArticle(article['title']);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(
              title: article['title'],
              content: offlineContent ?? article['content'],
            ),
          ),
        );
      },
      child: FutureBuilder<String?>(
        future: getOfflineArticle(article['title']),
        builder: (context, snapshot) {
          final isOffline = snapshot.hasData && snapshot.data != null;
          final isArchived = archivedArticlesBox.containsKey(article['title']);
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Icon(Icons.menu_book, size: 40, color: Colors.black),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      article['title'],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey[300]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (isOffline)
                      Icon(Icons.offline_pin, color: Colors.teal, size: 20)
                    else
                      IconButton(
                        icon: Icon(Icons.download, color: Colors.redAccent),
                        onPressed: () async {
                          await saveArticleOffline(article['title'], article['content']);
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        isArchived ? Icons.unarchive : Icons.archive,
                        color: isArchived ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () async {
                        await toggleArchiveArticle(article['title'], article['content']);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
