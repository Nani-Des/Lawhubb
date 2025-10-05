import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _userId => _auth.currentUser?.uid;

  /// Public getter for userId
  static String? get userId => _auth.currentUser?.uid;

  /// Save a message
  static Future<void> saveMessage(String role, String text) async {
    if (_userId != null) {
      // 🔹 Save to Firestore if logged in
      await _firestore
          .collection("Chats")
          .doc(_userId)
          .collection("messages")
          .add({
        "role": role,
        "text": text,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      // 🔹 Save locally if guest
      final prefs = await SharedPreferences.getInstance();
      final messages = prefs.getStringList("guest_messages") ?? [];
      messages.add(jsonEncode({
        "role": role,
        "text": text,
        "createdAt": DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList("guest_messages", messages);
    }
  }

  /// Get Firestore messages stream (only if logged in)
  static Stream<QuerySnapshot>? getMessagesStream() {
    if (_userId == null) return null;
    return _firestore
        .collection("Chats")
        .doc(_userId)
        .collection("messages")
        .orderBy("createdAt", descending: false)
        .snapshots();
  }

  /// Get local messages for guest users
  static Future<List<Map<String, dynamic>>> getLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messages = prefs.getStringList("guest_messages") ?? [];
    return messages.map((msg) => jsonDecode(msg) as Map<String, dynamic>).toList();
  }

  /// Clear guest chat
  static Future<void> clearLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("guest_messages");
  }
}
