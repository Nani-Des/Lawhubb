import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nhap/Services/news_feed_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsStandApp extends StatelessWidget {
  const NewsStandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Law News Stand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const NewsStandPage(),
    );
  }
}

class NewsStandPage extends StatefulWidget {
  const NewsStandPage({super.key});

  @override
  State<NewsStandPage> createState() => _NewsStandPageState();
}

class _NewsStandPageState extends State<NewsStandPage> {
  List<Map<String, dynamic>> _lawData = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews({bool refresh = false}) async {
    setState(() {
      _loading = true;
      if (refresh) _error = null;
    });

    try {
      final categories =
          await NewsFeedService.instance.fetchCategories(forceRefresh: refresh);
      if (!mounted) return;
      setState(() {
        _lawData = categories.map((c) => c.toLawDataMap()).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load news. Pull down to retry.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) return _lawData;
    final q = _searchQuery.toLowerCase();
    return _lawData
        .map((cat) {
          final articles = (cat['articles'] as List)
              .where((a) {
                final m = a as Map<String, dynamic>;
                final title = '${m['title']}'.toLowerCase();
                final content = '${m['content']}'.toLowerCase();
                return title.contains(q) || content.contains(q);
              })
              .toList();
          if (articles.isEmpty) return null;
          return {...cat, 'articles': articles};
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get _allArticles {
    return _filteredCategories
        .expand((c) => (c['articles'] as List).cast<Map<String, dynamic>>())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Law News Stand',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh feed',
            onPressed: _loading ? null : () => _loadNews(refresh: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadNews(refresh: true),
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _lawData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    }

    if (_lawData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No articles available')),
        ],
      );
    }

    final articles = _allArticles;
    final headline = articles.isNotEmpty ? articles.first : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.orange[800], fontSize: 13),
              ),
            ),
          if (headline != null) _buildHeadline(headline),
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search articles...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filteredCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = _filteredCategories[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryPage(category: category),
                      ),
                    );
                  },
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'] as IconData? ?? Icons.article,
                          size: 30,
                          color: Colors.indigo,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category['category'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Latest Articles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Updated from live feeds',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...articles.map(_buildArticleCard),
        ],
      ),
    );
  }

  Widget _buildHeadline(Map<String, dynamic> article) {
    return GestureDetector(
      onTap: () => _openArticle(context, article),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[800],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _articleImage(article['image'] as String?, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  article['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: _articleImage(article['image'] as String?),
          ),
        ),
        title: Text(
          article['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          article['content'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openArticle(context, article),
      ),
    );
  }

  Widget _articleImage(String? url, {BoxFit fit = BoxFit.cover}) {
    final src = url?.trim() ?? '';
    if (src.isEmpty) {
      return Container(
        color: Colors.grey[700],
        child: const Icon(Icons.article, color: Colors.white54),
      );
    }
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      placeholder: (_, __) => Container(color: Colors.grey[300]),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[700],
        child: const Icon(Icons.article, color: Colors.white54),
      ),
    );
  }

  void _openArticle(BuildContext context, Map<String, dynamic> article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailPage(
          title: article['title'] as String,
          content: article['content'] as String,
          image: article['image'] as String,
          articleUrl: article['url'] as String?,
        ),
      ),
    );
  }
}

class CategoryPage extends StatelessWidget {
  final Map<String, dynamic> category;

  const CategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final List articles = category['articles'] as List;
    return Scaffold(
      appBar: AppBar(
        title: Text(category['category'] as String),
        foregroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: article['image'] as String,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.article, size: 40),
                ),
              ),
              title: Text(
                article['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                article['content'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailPage(
                      title: article['title'] as String,
                      content: article['content'] as String,
                      image: article['image'] as String,
                      articleUrl: article['url'] as String?,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ArticleDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final String image;
  final String? articleUrl;

  const ArticleDetailPage({
    super.key,
    required this.title,
    required this.content,
    required this.image,
    this.articleUrl,
  });

  Future<void> _openInBrowser(BuildContext context) async {
    final url = articleUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open article link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title.length > 32 ? '${title.substring(0, 32)}…' : title,
        ),
        foregroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (articleUrl != null && articleUrl!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Read full article',
              onPressed: () => _openInBrowser(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: image,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: const Icon(Icons.article, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            if (articleUrl != null && articleUrl!.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInBrowser(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Read full article online'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
