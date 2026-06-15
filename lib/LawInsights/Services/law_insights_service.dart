import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LawInsightsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'law_insights';

  /// How long insights remain visible in feeds and saved libraries.
  static const int retentionDays = 60;

  DateTime get _retentionCutoff =>
      DateTime.now().subtract(const Duration(days: retentionDays));

  CollectionReference<Map<String, dynamic>> _savedInsightsRef(String userId) =>
      _firestore
          .collection('Users')
          .doc(userId)
          .collection('saved_law_insights');

  // Get all insights stream (non-expired only)
  Stream<QuerySnapshot> getInsightsStream() {
    return _firestore
        .collection(_collection)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_retentionCutoff))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get insights by category
  Stream<QuerySnapshot> getInsightsByCategoryStream(String category) {
    return _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_retentionCutoff))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get trending insights (by views + comments)
  Stream<QuerySnapshot> getTrendingInsightsStream() {
    return _firestore
        .collection(_collection)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_retentionCutoff))
        .orderBy('engagementScore', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Saved insights for the current user (snapshot stored locally per user).
  Stream<QuerySnapshot> getSavedInsightsStream(String userId) {
    return _savedInsightsRef(userId)
        .where('savedAt', isGreaterThan: Timestamp.fromDate(_retentionCutoff))
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  Future<bool> isInsightSaved(String userId, String insightId) async {
    final doc = await _savedInsightsRef(userId).doc(insightId).get();
    return doc.exists;
  }

  Stream<bool> watchInsightSaved(String userId, String insightId) {
    return _savedInsightsRef(userId)
        .doc(insightId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<void> saveInsight(
    String userId,
    String insightId,
    Map<String, dynamic> insightData,
  ) async {
    final expiresAt = insightData['expiresAt'] as Timestamp?;
    final createdAt = insightData['createdAt'] as Timestamp?;
    final retentionExpires = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: retentionDays)),
    );

    await _savedInsightsRef(userId).doc(insightId).set({
      'insightId': insightId,
      'savedAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt ?? retentionExpires,
      'title': insightData['title'] ?? '',
      'description': insightData['description'] ?? '',
      'category': insightData['category'] ?? '',
      'videoUrl': insightData['videoUrl'] ?? '',
      'thumbnailUrl': insightData['thumbnailUrl'] ?? '',
      'userId': insightData['userId'] ?? '',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'views': insightData['views'] ?? 0,
      'commentsCount': insightData['commentsCount'] ?? 0,
      'likes': insightData['likes'] ?? 0,
      'likedBy': insightData['likedBy'] ?? [],
      'viewedBy': insightData['viewedBy'] ?? [],
      'externalPlatforms': insightData['externalPlatforms'] ?? {},
    });
  }

  Future<void> unsaveInsight(String userId, String insightId) async {
    await _savedInsightsRef(userId).doc(insightId).delete();
  }

  Future<void> cleanExpiredSavedInsights(String userId) async {
    final expired = await _savedInsightsRef(userId)
        .where('savedAt', isLessThan: Timestamp.fromDate(_retentionCutoff))
        .get();

    if (expired.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in expired.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Create a new insight
  Future<String> createInsight({
    required String userId,
    required String title,
    required String description,
    required String category,
    String? videoUrl,
    String? thumbnailUrl,
    Map<String, String>? externalPlatforms,
  }) async {
    final insightRef = _firestore.collection(_collection).doc();

    final insightData = {
      'insightId': insightRef.id,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'videoUrl': videoUrl ?? '',
      'thumbnailUrl': thumbnailUrl ?? '',
      'views': 0,
      'viewedBy': [],
      'commentsCount': 0,
      'likes': 0,
      'likedBy': [],
      'engagementScore': 0, // views + comments * 2
      'externalPlatforms': externalPlatforms ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: LawInsightsService.retentionDays)),
      ),
      'isActive': true,
    };

    await insightRef.set(insightData);

    // Update user's insights count
    await _firestore.collection('Users').doc(userId).update({
      'insightsCount': FieldValue.increment(1),
    });

    return insightRef.id;
  }

  // Increment views (only once per user)
  Future<void> incrementViews(String insightId, String userId) async {
    final insightRef = _firestore.collection(_collection).doc(insightId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(insightRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final viewedBy = List<String>.from(data['viewedBy'] ?? []);
      
      // If user has already viewed, don't increment
      if (viewedBy.contains(userId)) return;

      // Add user to viewedBy array
      viewedBy.add(userId);
      final newViews = viewedBy.length;
      final commentsCount = (data['commentsCount'] as int?) ?? 0;
      final engagementScore = newViews + (commentsCount * 2);

      transaction.update(insightRef, {
        'views': newViews,
        'viewedBy': viewedBy,
        'engagementScore': engagementScore,
      });
    });
  }

  // Add comment
  Future<void> addComment({
    required String insightId,
    required String userId,
    required String userName,
    required String userPic,
    required String comment,
  }) async {
    final commentRef = _firestore
        .collection(_collection)
        .doc(insightId)
        .collection('comments')
        .doc();

    await commentRef.set({
      'commentId': commentRef.id,
      'userId': userId,
      'userName': userName,
      'userPic': userPic,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update comments count and engagement score
    final insightRef = _firestore.collection(_collection).doc(insightId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(insightRef);
      if (!snapshot.exists) return;

      final views = (snapshot.data()?['views'] as int?) ?? 0;
      final viewedBy = List<String>.from(snapshot.data()?['viewedBy'] ?? []);
      final currentComments = (snapshot.data()?['commentsCount'] as int?) ?? 0;
      final newComments = currentComments + 1;
      final engagementScore = viewedBy.length + (newComments * 2);

      transaction.update(insightRef, {
        'commentsCount': newComments,
        'engagementScore': engagementScore,
      });
    });
  }

  // Toggle like
  Future<void> toggleLike(String insightId, String userId) async {
    final insightRef = _firestore.collection(_collection).doc(insightId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(insightRef);
      if (!snapshot.exists) return;

      final likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
      final isLiked = likedBy.contains(userId);

      if (isLiked) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      transaction.update(insightRef, {
        'likes': likedBy.length,
        'likedBy': likedBy,
      });
    });
  }

  // Get comments stream
  Stream<QuerySnapshot> getCommentsStream(String insightId) {
    return _firestore
        .collection(_collection)
        .doc(insightId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Clean expired insights (should be called periodically)
  Future<void> cleanExpiredInsights() async {
    final now = Timestamp.now();
    final expiredInsights = await _firestore
        .collection(_collection)
        .where('expiresAt', isLessThan: now)
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in expiredInsights.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    await batch.commit();
  }

  // Update insight
  Future<void> updateInsight({
    required String insightId,
    required String title,
    required String description,
    required String category,
    String? videoUrl,
  }) async {
    final insightRef = _firestore.collection(_collection).doc(insightId);

    final updateData = <String, dynamic>{
      'title': title,
      'description': description,
      'category': category,
    };

    if (videoUrl != null && videoUrl.isNotEmpty) {
      updateData['videoUrl'] = videoUrl;
      updateData['thumbnailUrl'] = videoUrl; // Using video URL as thumbnail placeholder
    }

    await insightRef.update(updateData);
  }

  // Delete insight
  Future<void> deleteInsight(String insightId, String userId) async {
    final insightRef = _firestore.collection(_collection).doc(insightId);
    final snapshot = await insightRef.get();

    if (snapshot.exists && snapshot.data()?['userId'] == userId) {
      // Delete the insight document
      await insightRef.delete();

      // Delete associated comments
      final commentsSnapshot = await insightRef.collection('comments').get();
      final batch = _firestore.batch();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Update user's insights count
      await _firestore.collection('Users').doc(userId).update({
        'insightsCount': FieldValue.increment(-1),
      });
    }
  }

  // Get user insights
  Future<QuerySnapshot> getUserInsights(String userId) async {
    return await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
  }

  // Create discussion space
  Future<String> createDiscussion({
    required String userId,
    required String title,
    required String description,
    required String category,
    String? relatedInsightId,
  }) async {
    final discussionRef = _firestore.collection('law_discussions').doc();

    final discussionData = {
      'discussionId': discussionRef.id,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'relatedInsightId': relatedInsightId ?? '',
      'participantsCount': 1,
      'messagesCount': 0,
      'lastActivity': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    await discussionRef.set(discussionData);

    // Add creator as participant
    await discussionRef.collection('participants').doc(userId).set({
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return discussionRef.id;
  }

  // Get discussions stream
  Stream<QuerySnapshot> getDiscussionsStream({String? category}) {
    if (category != null && category != 'All') {
      return _firestore
          .collection('law_discussions')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('lastActivity', descending: true)
          .snapshots();
    }
    return _firestore
        .collection('law_discussions')
        .where('isActive', isEqualTo: true)
        .orderBy('lastActivity', descending: true)
        .snapshots();
  }

  // Add message to discussion
  Future<void> addDiscussionMessage({
    required String discussionId,
    required String userId,
    required String userName,
    required String userPic,
    required String message,
  }) async {
    final messageRef = _firestore
        .collection('law_discussions')
        .doc(discussionId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'userId': userId,
      'userName': userName,
      'userPic': userPic,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update discussion last activity and message count
    final discussionRef = _firestore.collection('law_discussions').doc(discussionId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(discussionRef);
      if (!snapshot.exists) return;

      final currentCount = (snapshot.data()?['messagesCount'] as int?) ?? 0;
      transaction.update(discussionRef, {
        'messagesCount': currentCount + 1,
        'lastActivity': FieldValue.serverTimestamp(),
      });
    });
  }

  // Join discussion
  Future<void> joinDiscussion(String discussionId, String userId) async {
    final participantRef = _firestore
        .collection('law_discussions')
        .doc(discussionId)
        .collection('participants')
        .doc(userId);

    await participantRef.set({
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Update participants count
    final discussionRef = _firestore.collection('law_discussions').doc(discussionId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(discussionRef);
      if (!snapshot.exists) return;

      final currentCount = (snapshot.data()?['participantsCount'] as int?) ?? 0;
      transaction.update(discussionRef, {
        'participantsCount': currentCount + 1,
      });
    });
  }

  // Get discussion messages stream
  Stream<QuerySnapshot> getDiscussionMessagesStream(String discussionId) {
    return _firestore
        .collection('law_discussions')
        .doc(discussionId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}

