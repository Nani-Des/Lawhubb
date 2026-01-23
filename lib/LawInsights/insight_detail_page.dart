import 'package:flutter/material.dart';
import '../Forums/Public/Widgets/postcard_media.dart';

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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Legal Insight',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (videoUrl.isNotEmpty)
              VideoPlayerWidget(videoUrl: videoUrl),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insightData['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    insightData['description'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

