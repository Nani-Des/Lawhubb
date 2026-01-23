import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Follow a user
  Future<void> followUser(String userId, String userToFollowId) async {
    if (userId == userToFollowId) return;

    // Check if already following (prevent duplicate)
    final alreadyFollowing = await isFollowing(userId, userToFollowId);
    if (alreadyFollowing) return;

    // Add to following list
    await _firestore
        .collection('Follows')
        .doc(userId)
        .collection('following')
        .doc(userToFollowId)
        .set({
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Add to followers list
    await _firestore
        .collection('Follows')
        .doc(userToFollowId)
        .collection('followers')
        .doc(userId)
        .set({
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Update follower count for followed user
    await _firestore.collection('Users').doc(userToFollowId).update({
      'followersCount': FieldValue.increment(1),
    });

    // Update following count for current user
    await _firestore.collection('Users').doc(userId).update({
      'followingCount': FieldValue.increment(1),
    });
  }

  // Unfollow a user
  Future<void> unfollowUser(String userId, String userToUnfollowId) async {
    // Remove from following list
    await _firestore
        .collection('Follows')
        .doc(userId)
        .collection('following')
        .doc(userToUnfollowId)
        .delete();

    // Remove from followers list
    await _firestore
        .collection('Follows')
        .doc(userToUnfollowId)
        .collection('followers')
        .doc(userId)
        .delete();

    // Update follower count for unfollowed user
    await _firestore.collection('Users').doc(userToUnfollowId).update({
      'followersCount': FieldValue.increment(-1),
    });

    // Update following count for current user
    await _firestore.collection('Users').doc(userId).update({
      'followingCount': FieldValue.increment(-1),
    });
  }

  // Check if user is following another user
  Future<bool> isFollowing(String userId, String otherUserId) async {
    if (userId == otherUserId) return false;
    
    final doc = await _firestore
        .collection('Follows')
        .doc(userId)
        .collection('following')
        .doc(otherUserId)
        .get();
    
    return doc.exists;
  }

  // Get list of users that the current user is following
  Future<List<String>> getFollowingList(String userId) async {
    final snapshot = await _firestore
        .collection('Follows')
        .doc(userId)
        .collection('following')
        .get();
    
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Get stream of following list
  Stream<List<String>> getFollowingListStream(String userId) {
    return _firestore
        .collection('Follows')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get list of followers
  Future<List<String>> getFollowersList(String userId) async {
    final snapshot = await _firestore
        .collection('Follows')
        .doc(userId)
        .collection('followers')
        .get();
    
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Get follower count
  Future<int> getFollowerCount(String userId) async {
    final userDoc = await _firestore.collection('Users').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      return (data?['followersCount'] as int?) ?? 0;
    }
    return 0;
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    final userDoc = await _firestore.collection('Users').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      return (data?['followingCount'] as int?) ?? 0;
    }
    return 0;
  }
}

