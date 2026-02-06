import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatList extends StatefulWidget {
  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view chats', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Chats')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'No chats yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation to see it here',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Convert to list of chat documents
        final chats = snapshot.data!.docs;

        // Build a list of chat data with sorting info
        return FutureBuilder<List<_ChatItem>>(
          future: _buildChatItems(chats, currentUser.uid),
          builder: (context, chatItemsSnapshot) {
            if (!chatItemsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final sortedChats = chatItemsSnapshot.data!;
            
            if (sortedChats.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'No chats yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: sortedChats.length,
              itemBuilder: (context, index) {
                final chatItem = sortedChats[index];
                return _buildChatTile(chatItem, currentUser.uid);
              },
            );
          },
        );
      },
    );
  }

  Future<List<_ChatItem>> _buildChatItems(List<QueryDocumentSnapshot> chats, String currentUserId) async {
    List<_ChatItem> chatItems = [];

    for (var chatDoc in chats) {
      try {
        final chatId = chatDoc.id;

        // Get last message timestamp
        final lastMessageQuery = await FirebaseFirestore.instance
            .collection('Chats')
            .doc(chatId)
            .collection('Messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        Timestamp? lastMessageTimestamp;
        if (lastMessageQuery.docs.isNotEmpty) {
          lastMessageTimestamp = lastMessageQuery.docs.first.data()['timestamp'] as Timestamp?;
        }

        // Get unread count
        final unreadQuery = await FirebaseFirestore.instance
            .collection('Chats')
            .doc(chatId)
            .collection('Messages')
            .where('recipientId', isEqualTo: currentUserId)
            .where('read', isEqualTo: false)
            .get();

        final unreadCount = unreadQuery.docs.length;
        final hasUnread = unreadCount > 0;

        chatItems.add(_ChatItem(
          chatDoc: chatDoc,
          lastMessageTimestamp: lastMessageTimestamp,
          hasUnread: hasUnread,
          unreadCount: unreadCount,
        ));
      } catch (e) {
        debugPrint('Error processing chat ${chatDoc.id}: $e');
      }
    }

    // Sort: unread first, then by timestamp (most recent first)
    chatItems.sort((a, b) {
      // First, prioritize unread messages
      if (a.hasUnread && !b.hasUnread) return -1;
      if (!a.hasUnread && b.hasUnread) return 1;

      // Then sort by timestamp (most recent first)
      if (a.lastMessageTimestamp == null && b.lastMessageTimestamp == null) return 0;
      if (a.lastMessageTimestamp == null) return 1;
      if (b.lastMessageTimestamp == null) return -1;
      
      return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
    });

    return chatItems;
  }

  Widget _buildChatTile(_ChatItem chatItem, String currentUserId) {
    final chatDoc = chatItem.chatDoc;
    final chatId = chatDoc.id;
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final participants = chatData['participants'] as List;
    
    String otherUserId = participants.firstWhere((id) => id != currentUserId);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .doc(otherUserId)
          .get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
        
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Consultations')
              .doc(chatId)
              .snapshots(),
          builder: (context, consultSnapshot) {
            bool isActiveConsultation = consultSnapshot.hasData &&
                consultSnapshot.data!.exists &&
                (consultSnapshot.data!.data() as Map<String, dynamic>)['status'] ==
                    'active';

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Chats')
                  .doc(chatId)
                  .collection('Messages')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, msgSnapshot) {
                String preview = 'No messages';
                if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                  final lastMessage = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final messageType = lastMessage['type'] ?? 'text';
                  final content = lastMessage['content'] ?? '';
                  preview = messageType == 'audio' 
                      ? '🎤 Voice message' 
                      : (content.isNotEmpty ? content : 'Message');
                }

                return Container(
                  color: isActiveConsultation ? Colors.redAccent.withOpacity(0.1) : null,
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: userData['User Pic'] != null &&
                              userData['User Pic'].toString().isNotEmpty
                              ? NetworkImage(userData['User Pic'])
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: userData['User Pic'] == null ||
                              userData['User Pic'].toString().isEmpty
                              ? Text(
                                  userData['Fname'] != null && userData['Fname'].toString().isNotEmpty
                                      ? userData['Fname'][0].toString().toUpperCase()
                                      : 'U',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        // Online indicator
                        if (userData['isOnline'] == true)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      '${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}'.trim(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: chatItem.hasUnread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      preview,
                      maxLines: 1,
                      style: TextStyle(
                        color: chatItem.hasUnread ? Colors.white : Colors.grey[500],
                        fontWeight: chatItem.hasUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chatItem.unreadCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              chatItem.unreadCount > 99 ? '99+' : chatItem.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isActiveConsultation)
                          const Icon(Icons.videocam, color: Colors.green, size: 20),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatId,
                            recipientId: otherUserId,
                            recipientName: '${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}'.trim(),
                            recipientPic: userData['User Pic'] ?? '',
                            recipientRole: userData['Role'] ?? false,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChatItem {
  final QueryDocumentSnapshot chatDoc;
  final Timestamp? lastMessageTimestamp;
  final bool hasUnread;
  final int unreadCount;

  _ChatItem({
    required this.chatDoc,
    required this.lastMessageTimestamp,
    required this.hasUnread,
    required this.unreadCount,
  });
}
