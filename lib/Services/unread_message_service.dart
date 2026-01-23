import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UnreadMessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get total unread message count for current user
  Stream<int> getTotalUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    // Get all chats where user is a participant
    return _firestore
        .collection('Chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;

      for (var chatDoc in chatsSnapshot.docs) {
        try {
          final unreadSnapshot = await _firestore
              .collection('Chats')
              .doc(chatDoc.id)
              .collection('Messages')
              .where('recipientId', isEqualTo: currentUser.uid)
              .where('read', isEqualTo: false)
              .get();

          totalUnread += unreadSnapshot.docs.length;
        } catch (e) {
          // Skip if there's an error
          continue;
        }
      }

      return totalUnread;
    });
  }

  /// Get unread count for a specific chat
  Stream<int> getChatUnreadCount(String chatId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('Chats')
        .doc(chatId)
        .collection('Messages')
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

