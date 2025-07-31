import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class SearchScreen extends StatelessWidget {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
          ),
          onChanged: (value) => (context as Element).markNeedsBuild(),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('Users').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          var users = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String fullName = '${data['Fname']} ${data['Lname']}';
            return fullName
                .toLowerCase()
                .contains(searchController.text.toLowerCase());
          }).toList();
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index].data() as Map<String, dynamic>;
              if (user['User ID'] == FirebaseAuth.instance.currentUser!.uid)
                return SizedBox.shrink();
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                  user['User Pic'] != null && user['User Pic'].isNotEmpty
                      ? NetworkImage(user['User Pic'])
                      : null,
                  child: user['User Pic'] == null || user['User Pic'].isEmpty
                      ? Text(user['Fname'][0])
                      : null,
                ),
                title: Text('${user['Fname']} ${user['Lname']}'),
                subtitle: Text(user['Role'] ? 'Doctor' : 'User'),
                onTap: () async {
                  String chatId = await _getOrCreateChat(
                    FirebaseAuth.instance.currentUser!.uid,
                    user['User ID'],
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chatId,
                        recipientId: user['User ID'],
                        recipientName: '${user['Fname']} ${user['Lname']}',
                        recipientPic: user['User Pic'] ?? '',
                        recipientRole: user['Role'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getOrCreateChat(String user1Id, String user2Id) async {
    String chatId = user1Id.compareTo(user2Id) < 0
        ? '${user1Id}_$user2Id'
        : '${user2Id}_$user1Id';
    var chatDoc =
    await FirebaseFirestore.instance.collection('Chats').doc(chatId).get();
    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('Chats').doc(chatId).set({
        'participants': [user1Id, user2Id],
        'lastMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }
}