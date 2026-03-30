import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool _showOnlyLawyers = true;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() {}),
        ),
        actions: [
          Row(
            children: [
              Text(
                'Lawyers only',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              Switch(
                value: _showOnlyLawyers,
                onChanged: (val) => setState(() => _showOnlyLawyers = val),
                activeColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('Users').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final currentUid = FirebaseAuth.instance.currentUser!.uid;
          var users = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['User ID'] == currentUid) return false;
            if (_showOnlyLawyers && data['Role'] != true) return false;
            final fullName = '${data['Fname']} ${data['Lname']}';
            return fullName
                .toLowerCase()
                .contains(searchController.text.toLowerCase());
          }).toList();

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search, size: 60, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    _showOnlyLawyers
                        ? 'No lawyers found'
                        : 'No users found',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (_showOnlyLawyers) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _showOnlyLawyers = false),
                      child: const Text('Show all users'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index].data() as Map<String, dynamic>;
              final isLawyer = user['Role'] == true;
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
                subtitle: Text(isLawyer ? 'Lawyer' : 'User'),
                trailing: isLawyer
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent[700],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Lawyer',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      )
                    : null,
                onTap: () async {
                  String chatId = await _getOrCreateChat(
                    currentUid,
                    user['User ID'],
                  );
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chatId,
                        recipientId: user['User ID'],
                        recipientName: '${user['Fname']} ${user['Lname']}',
                        recipientPic: user['User Pic'] ?? '',
                        recipientRole: user['Role'] ?? false,
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
