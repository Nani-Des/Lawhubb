import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'consultation_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String recipientPic;
  final bool recipientRole;

  ChatScreen({
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPic,
    required this.recipientRole,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
              widget.recipientPic.isNotEmpty ? NetworkImage(widget.recipientPic) : null,
              child: widget.recipientPic.isEmpty ? Text(widget.recipientName[0]) : null,
            ),
            SizedBox(width: 10),
            Text(widget.recipientName),
          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Consultations')
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return IconButton(
                  icon: Icon(Icons.videocam),
                  onPressed: FirebaseAuth.instance.currentUser!.uid != widget.recipientId &&
                      widget.recipientRole
                      ? () async {
                    await FirebaseFirestore.instance
                        .collection('Consultations')
                        .doc(widget.chatId)
                        .set({
                      'chatId': widget.chatId,
                      'initiatorId': FirebaseAuth.instance.currentUser!.uid,
                      'recipientId': widget.recipientId,
                      'status': 'active',
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConsultationScreen(
                          channelName: widget.chatId,
                          isInitiator: true,
                        ),
                      ),
                    );
                  }
                      : null,
                );
              }
              var consultData = snapshot.data!.data() as Map<String, dynamic>;
              if (consultData['status'] == 'active') {
                return IconButton(
                  icon: Icon(Icons.videocam, color: Colors.green),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConsultationScreen(
                          channelName: widget.chatId,
                          isInitiator: consultData['initiatorId'] ==
                              FirebaseAuth.instance.currentUser!.uid,
                        ),
                      ),
                    );
                  },
                );
              }
              return IconButton(
                icon: Icon(Icons.videocam),
                onPressed: FirebaseAuth.instance.currentUser!.uid != widget.recipientId &&
                    widget.recipientRole
                    ? () async {
                  await FirebaseFirestore.instance
                      .collection('Consultations')
                      .doc(widget.chatId)
                      .set({
                    'chatId': widget.chatId,
                    'initiatorId': FirebaseAuth.instance.currentUser!.uid,
                    'recipientId': widget.recipientId,
                    'status': 'active',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsultationScreen(
                        channelName: widget.chatId,
                        isInitiator: true,
                      ),
                    ),
                  );
                }
                    : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('Chats')
                  .doc(widget.chatId)
                  .collection('Messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    bool isMe = message['senderId'] == FirebaseAuth.instance.currentUser!.uid;
                    return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('Users')
                          .doc(message['senderId'])
                          .get(),
                      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                        if (!userSnapshot.hasData) return SizedBox.shrink();
                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: !isMe
                              ? CircleAvatar(
                            backgroundImage: userData['User Pic'] != null &&
                                userData['User Pic'].isNotEmpty
                                ? NetworkImage(userData['User Pic'])
                                : null,
                            child: userData['User Pic'] == null ||
                                userData['User Pic'].isEmpty
                                ? Text(userData['Fname'][0])
                                : null,
                          )
                              : null,
                          trailing: isMe
                              ? CircleAvatar(
                            backgroundImage: userData['User Pic'] != null &&
                                userData['User Pic'].isNotEmpty
                                ? NetworkImage(userData['User Pic'])
                                : null,
                            child: userData['User Pic'] == null ||
                                userData['User Pic'].isEmpty
                                ? Text(userData['Fname'][0])
                                : null,
                          )
                              : null,
                          title: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.teal[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['content'],
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy HH:mm')
                                        .format(message['timestamp'].toDate()),
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (isMe)
                                    Icon(
                                      message['read'] ? Icons.done_all : Icons.done,
                                      size: 16,
                                      color: message['read'] ? Colors.blue : Colors.grey,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () async {
                    if (messageController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('Chats')
                          .doc(widget.chatId)
                          .collection('Messages')
                          .add({
                        'content': messageController.text,
                        'senderId': FirebaseAuth.instance.currentUser!.uid,
                        'recipientId': widget.recipientId,
                        'timestamp': FieldValue.serverTimestamp(),
                        'read': false,
                      });
                      await FirebaseFirestore.instance
                          .collection('Chats')
                          .doc(widget.chatId)
                          .update({
                        'lastMessage': messageController.text,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}