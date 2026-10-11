import 'package:cloud_firestore/cloud_firestore.dart';

class ForumFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new post with the document ID set as the "Post ID"
  Future<void> createPost(
      String userId,
      String content,
      String? imageUrl,
      String? videoUrl,
      ) async {
    // Create a new post document with an auto-generated document ID
    DocumentReference postRef = _firestore.collection('Posts').doc(); // Auto-generated ID
    String postId = postRef.id; // Capture the document ID

    await postRef.set({
      'Post ID': postId, // Store the document ID in the "Post ID" field
      'User ID': userId,
      'Content': content,
      'ImageURL': imageUrl,
      'VideoURL': videoUrl,
      'Timestamp': FieldValue.serverTimestamp(),
      'Likes': 0,
    });
  }

  /// Reposts an existing post to the current user's feed.
  Future<void> repostPost({
    required String userId,
    required Map<String, dynamic> originalPost,
  }) async {
    final originalId =
        (originalPost['id'] ?? originalPost['Post ID'] ?? '').toString();
    if (originalId.isEmpty) {
      throw StateError('missing_post_id');
    }

    // Avoid duplicate reposts of the same post by the same user.
    final existing = await _firestore
        .collection('Posts')
        .where('User ID', isEqualTo: userId)
        .where('repostOf', isEqualTo: originalId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('already_reposted');
    }

    final postRef = _firestore.collection('Posts').doc();
    await postRef.set({
      'Post ID': postRef.id,
      'User ID': userId,
      'Content': originalPost['Content'] ?? '',
      'ImageURL': originalPost['ImageURL'],
      'VideoURL': originalPost['VideoURL'],
      'Timestamp': FieldValue.serverTimestamp(),
      'Likes': 0,
      'repostOf': originalId,
      'originalUserId': originalPost['User ID'] ?? '',
      'isRepost': true,
    });

    await _firestore.collection('Posts').doc(originalId).set({
      'Reposts': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Fetches all posts, ordered by timestamp in descending order
  Future<List<Map<String, dynamic>>> fetchPosts({bool fromServer = false}) async {
    QuerySnapshot snapshot = await _firestore
        .collection('Posts')
        .orderBy('Timestamp', descending: true)
        .get(fromServer ? const GetOptions(source: Source.server) : null);

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  /// Increments the "Likes" count for a specific post
  Future<void> likePost(String postId) async {
    DocumentReference postRef = _firestore.collection('Posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      int newLikes = (snapshot['Likes'] as int) + 1;
      transaction.update(postRef, {'Likes': newLikes});
    });
  }
}
