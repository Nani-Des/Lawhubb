import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Forums/Public/Widgets/postcard_media.dart';

Future<String> _loadAuthorLabel(Map<String, dynamic> insightData) async {
  final userId = insightData['userId'] as String?;
  if (userId == null) return 'Member';
  final d =
      await FirebaseFirestore.instance.collection('Users').doc(userId).get();
  if (!d.exists) return 'Member';
  final u = d.data() ?? {};
  final n = '${u['Fname'] ?? ''} ${u['Lname'] ?? ''}'.trim();
  return n.isEmpty ? 'Member' : n;
}

/// Full-screen insight: video (if any), title, full description, author & metadata.
class InsightDetailPage extends StatelessWidget {
  final String insightId;
  final Map<String, dynamic> insightData;

  const InsightDetailPage({
    required this.insightId,
    required this.insightData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final videoUrl = insightData['videoUrl'] as String? ?? '';
    final category = insightData['category'] as String? ?? '';
    final createdAt = insightData['createdAt'] as Timestamp?;
    final views = (insightData['views'] is int)
        ? insightData['views'] as int
        : int.tryParse('${insightData['views']}') ?? 0;
    final likes = (insightData['likes'] is int)
        ? insightData['likes'] as int
        : int.tryParse('${insightData['likes']}') ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          insightData['title'] as String? ?? 'Legal Insight',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<String>(
        future: _loadAuthorLabel(insightData),
        builder: (context, authorSnap) {
          final authorLabel =
              authorSnap.connectionState == ConnectionState.done
                  ? (authorSnap.data ?? 'Member')
                  : '…';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (videoUrl.isNotEmpty) VideoPlayerWidget(videoUrl: videoUrl),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (category.isNotEmpty)
                            Chip(
                              label: Text(category),
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.grey[850],
                              side: BorderSide(color: Colors.grey[700]!),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          _MetaPill(
                            icon: Icons.person_outline,
                            text: authorLabel,
                          ),
                          if (createdAt != null)
                            _MetaPill(
                              icon: Icons.schedule,
                              text: DateFormat.yMMMd()
                                  .add_jm()
                                  .format(createdAt.toDate()),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatChip(icon: Icons.visibility, value: views),
                          const SizedBox(width: 12),
                          _StatChip(icon: Icons.favorite_outline, value: likes),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        insightData['title'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        insightData['description'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 16,
                          height: 1.55,
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
