import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('Chats')
          .where('participants', arrayContains: currentUser!.uid)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chat = snapshot.data!.docs[index];
            String otherUserId = chat['participants']
                .firstWhere((id) => id != currentUser.uid);
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return SizedBox.shrink();
                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Consultations')
                      .doc(chat.id)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<DocumentSnapshot> consultSnapshot) {
                    bool isActiveConsultation = consultSnapshot.hasData &&
                        consultSnapshot.data!.exists &&
                        (consultSnapshot.data!.data() as Map<String, dynamic>)['status'] ==
                            'active';
                    return Container(
                      color: isActiveConsultation ? Colors.teal[50] : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userData['User Pic'] != null &&
                              userData['User Pic'].isNotEmpty
                              ? NetworkImage(userData['User Pic'])
                              : null,
                          child: userData['User Pic'] == null ||
                              userData['User Pic'].isEmpty
                              ? Text(userData['Fname'][0])
                              : null,
                        ),
                        title: Text('${userData['Fname']} ${userData['Lname']}'),
                        subtitle: StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('Chats')
                              .doc(chat.id)
                              .collection('Messages')
                              .orderBy('timestamp', descending: true)
                              .limit(1)
                              .snapshots(),
                          builder: (context, AsyncSnapshot<QuerySnapshot> msgSnapshot) {
                            if (!msgSnapshot.hasData || msgSnapshot.data!.docs.isEmpty)
                              return Text('No messages');
                            var lastMessage = msgSnapshot.data!.docs.first;
                            return Text(
                              lastMessage['content'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        trailing: isActiveConsultation
                            ? Icon(Icons.videocam, color: Colors.green)
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatId: chat.id,
                                recipientId: otherUserId,
                                recipientName: '${userData['Fname']} ${userData['Lname']}',
                                recipientPic: userData['User Pic'] ?? '',recipientRole: userData['Role'] ?? 'true',
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
      },
    );
  }
}