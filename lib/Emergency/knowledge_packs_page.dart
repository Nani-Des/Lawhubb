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
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut),
    );
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
        content: Text("Downloaded: $title"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          content: Text("Unarchived: $title"),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      await archivedArticlesBox.put(title, content);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Archived: $title"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      final matches = articles
          .where((a) => a['title'].toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
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
        return Container(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 4,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
              Icon(Icons.book, color: Colors.blueAccent, size: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: _buildLoadingState(),
      );
    }

    final filteredArticles = getFilteredArticles();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          showArchived ? "Archived Library" : "Knowledge Library",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              showArchived ? Icons.library_books : Icons.archive,
              color: Colors.black87,
            ),
            onPressed: () => setState(() => showArchived = !showArchived),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: filteredArticles.isEmpty
                ? _buildEmptyState()
                : ListView(
              padding: EdgeInsets.symmetric(vertical: 12),
              children: filteredArticles.entries.map((entry) {
                return _buildCategoryShelf(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search knowledge packs...",
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSophisticatedProgressIndicator(),
          SizedBox(height: 12),
          Text(
            "Loading Knowledge Packs...",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
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
          Icon(Icons.book_outlined, size: 60, color: Colors.grey[400]),
          SizedBox(height: 12),
          Text(
            showArchived ? "No Archived Packs" : "No Knowledge Packs",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 6),
          Text(
            showArchived
                ? "Archive some packs to see them here!"
                : "Check back later for new content.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryShelf(String category, List<Map<String, dynamic>> articles) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 160, // Reduced height for compact cards
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
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
            width: 120, // Reduced width for smaller, sophisticated cards
            margin: EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 80, // Reduced height for compact header
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    gradient: LinearGradient(
                      colors: [Colors.blueGrey[700]!, Colors.blueGrey[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 28, // Smaller icon
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    article['title'],
                    style: TextStyle(
                      fontSize: 12, // Smaller font size
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
                Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (!isOffline) {
                            await saveArticleOffline(article['title'], article['content']);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isOffline ? Colors.green[50] : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOffline ? Icons.check_circle : Icons.download,
                            color: isOffline ? Colors.green[600] : Colors.grey[600],
                            size: 18, // Smaller icon
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await toggleArchiveArticle(article['title'], article['content']);
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isArchived ? Colors.orange[50] : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isArchived ? Icons.unarchive : Icons.archive,
                            color: isArchived ? Colors.orange[600] : Colors.grey[600],
                            size: 18, // Smaller icon
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}