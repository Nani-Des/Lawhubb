import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:xml/xml.dart';

import 'config_service.dart';

/// One article for Law News Stand.
class NewsArticleItem {
  final String title;
  final String summary;
  final String? imageUrl;
  final String? articleUrl;
  final String category;
  final DateTime? publishedAt;

  const NewsArticleItem({
    required this.title,
    required this.summary,
    this.imageUrl,
    this.articleUrl,
    required this.category,
    this.publishedAt,
  });

  Map<String, dynamic> toDisplayMap() => {
        'title': title,
        'content': summary,
        'image': imageUrl ??
            'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800',
        'url': articleUrl,
        'category': category,
      };
}

/// Category bucket for the news stand UI.
class NewsCategory {
  final String name;
  final IconData icon;
  final List<NewsArticleItem> articles;

  const NewsCategory({
    required this.name,
    required this.icon,
    required this.articles,
  });

  Map<String, dynamic> toLawDataMap() => {
        'category': name,
        'icon': icon,
        'articles': articles.map((a) => a.toDisplayMap()).toList(),
      };
}

/// Fetches legal news from Google News RSS (no key) and optional NewsAPI.
class NewsFeedService {
  NewsFeedService._();
  static final NewsFeedService instance = NewsFeedService._();

  static const String _defaultImage =
      'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800';

  static const List<({String name, String url})> _rssFeeds = [
    (
      name: 'Legal & Courts',
      url:
          'https://news.google.com/rss/search?q=law+court+legal&hl=en-US&gl=US&ceid=US:en',
    ),
    (
      name: 'Ghana & Africa',
      url:
          'https://news.google.com/rss/search?q=Ghana+legal+law+court&hl=en-GH&gl=GH&ceid=GH:en',
    ),
    (
      name: 'Business & Policy',
      url:
          'https://news.google.com/rss/search?q=business+regulation+policy+law&hl=en-US&gl=US&ceid=US:en',
    ),
  ];

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'User-Agent': 'LawHubb/1.0 (Flutter News Reader)'},
    ),
  );

  List<NewsCategory>? _cache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 30);

  Future<List<NewsCategory>> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cache!;
    }

    final allArticles = <NewsArticleItem>[];

    final apiKey = ConfigService().newsApiKey.trim();
    if (apiKey.isNotEmpty) {
      try {
        allArticles.addAll(await _fetchNewsApi(apiKey));
      } catch (e) {
        debugPrint('NewsAPI fetch failed: $e');
      }
    }

    for (final feed in _rssFeeds) {
      try {
        allArticles.addAll(await _fetchRssFeed(feed.name, feed.url));
      } catch (e) {
        debugPrint('RSS fetch failed (${feed.name}): $e');
      }
    }

    if (allArticles.isEmpty) {
      return _fallbackCategories();
    }

    final seen = <String>{};
    final unique = allArticles.where((a) {
      final key = a.title.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    unique.sort((a, b) {
      final ta = a.publishedAt;
      final tb = b.publishedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final buckets = <String, List<NewsArticleItem>>{};
    for (final a in unique) {
      buckets.putIfAbsent(a.category, () => []).add(a);
    }

    final categories = <NewsCategory>[];
    for (final feed in _rssFeeds) {
      final items = buckets[feed.name] ?? [];
      if (items.isNotEmpty) {
        categories.add(NewsCategory(
          name: feed.name,
          icon: _iconForCategory(feed.name),
          articles: items.take(12).toList(),
        ));
      }
    }

    final other = buckets['Top Headlines'] ?? [];
    if (other.isNotEmpty) {
      categories.insert(
        0,
        NewsCategory(
          name: 'Top Headlines',
          icon: Icons.newspaper,
          articles: other.take(10).toList(),
        ),
      );
    }

    _cache = categories.isNotEmpty ? categories : _fallbackCategories();
    _cacheTime = DateTime.now();
    return _cache!;
  }

  Future<List<NewsArticleItem>> _fetchRssFeed(String category, String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.isEmpty) return [];

    final doc = XmlDocument.parse(body);
    final items = <NewsArticleItem>[];

    for (final item in doc.findAllElements('item')) {
      final title = _stripHtml(_childText(item, 'title'));
      if (title.isEmpty) continue;

      final description = _stripHtml(
        _childText(item, 'description').isNotEmpty
            ? _childText(item, 'description')
            : _childText(item, 'content'),
      );
      final summary = description.length > 280
          ? '${description.substring(0, 277)}...'
          : (description.isEmpty ? title : description);

      final link = _childText(item, 'link');
      final pubDate = DateTime.tryParse(_childText(item, 'pubDate'));

      String? imageUrl = _extractImageFromDescription(
        _childText(item, 'description'),
      );

      items.add(NewsArticleItem(
        title: title,
        summary: summary,
        imageUrl: imageUrl,
        articleUrl: link.isNotEmpty ? link : null,
        category: category,
        publishedAt: pubDate,
      ));
      if (items.length >= 15) break;
    }
    return items;
  }

  String _childText(XmlElement parent, String localName) {
    final el = parent.getElement(localName);
    return el?.innerText.trim() ?? '';
  }

  String? _extractImageFromDescription(String html) {
    final match = RegExp(
      r'''src=['"](https?://[^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  Future<List<NewsArticleItem>> _fetchNewsApi(String apiKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://newsapi.org/v2/top-headlines',
      queryParameters: {
        'category': 'general',
        'language': 'en',
        'pageSize': 15,
        'apiKey': apiKey,
      },
    );

    final articles = response.data?['articles'] as List<dynamic>? ?? [];
    final items = <NewsArticleItem>[];

    for (final raw in articles) {
      if (raw is! Map<String, dynamic>) continue;
      final title = (raw['title'] as String?)?.trim() ?? '';
      if (title.isEmpty || title == '[Removed]') continue;

      final desc = _stripHtml(raw['description'] as String? ?? '');
      items.add(NewsArticleItem(
        title: title,
        summary: desc.isEmpty ? title : desc,
        imageUrl: raw['urlToImage'] as String?,
        articleUrl: raw['url'] as String?,
        category: 'Top Headlines',
        publishedAt: DateTime.tryParse(raw['publishedAt'] as String? ?? ''),
      ));
    }
    return items;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true), r'$1')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  IconData _iconForCategory(String name) {
    switch (name) {
      case 'Ghana & Africa':
        return Icons.public;
      case 'Business & Policy':
        return Icons.policy;
      case 'Top Headlines':
        return Icons.newspaper;
      default:
        return Icons.gavel;
    }
  }

  List<NewsCategory> _fallbackCategories() {
    return [
      NewsCategory(
        name: 'Legal & Courts',
        icon: Icons.gavel,
        articles: [
          NewsArticleItem(
            title: 'Law News Stand',
            summary:
                'Connect to the internet to load the latest legal headlines. '
                'Optional: set news_api_key in Firebase Remote Config for NewsAPI.org.',
            imageUrl: _defaultImage,
            category: 'Legal & Courts',
          ),
        ],
      ),
    ];
  }
}
