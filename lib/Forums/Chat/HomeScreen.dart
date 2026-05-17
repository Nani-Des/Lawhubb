import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Forums/Chat/search_screen.dart';
import '../Public/forum.dart';
import '../Public/Widgets/user_profile_screen.dart';
import 'chat_list.dart';
import '../../widgets/profile_avatar.dart';
import 'live_stream.dart';

class HomeScreen extends StatelessWidget {
  final int initialTabIndex; // 👈 New parameter (0 = Chats, 1 = Social Hubb)

  const HomeScreen({Key? key, this.initialTabIndex = 0}) : super(key: key);

  Future<void> _startPublicConsultation(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final chatId =
          'public_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final fullName =
      "${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}".trim();
      final userPic = userData['User Pic'] ?? '';

      final consultationRef =
      FirebaseFirestore.instance.collection('Consultations').doc(chatId);

      await consultationRef.set({
        'chatId': chatId,
        'initiatorId': currentUser.uid,
        'initiatorName': fullName,
        'initiatorPic': userPic,
        'recipientId': 'public',
        'status': 'active',
        'viewerCount': 0,
        'startTimestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveConsultationScreen(
              channelName: chatId,
              isInitiator: true,
              chatId: chatId,
              initiatorId: currentUser.uid,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting public consultation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start consultation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final loggedInUserId = currentUser.uid;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex, // 👈 Set the starting tab dynamically
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.chat, color: Colors.white), text: "Chats"),
              Tab(icon: Icon(Icons.forum, color: Colors.white), text: "Social Hubb"),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userId: loggedInUserId,
                      ),
                    ),
                  );
                },
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('Users')
                      .doc(currentUser.uid)
                      .get(),
                  builder: (context, snapshot) {
                    String? userPic;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                      snapshot.data!.data() as Map<String, dynamic>?;
                      userPic = data?['User Pic'];
                    }
                    return ProfileAvatar.circle(
                      imageUrl: userPic,
                      radius: 18,
                    );
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>  SearchScreen()));
              },
              icon: const Icon(Icons.search, color: Colors.white),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "🗣️ Chats",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(thickness: 1.2),
                Expanded(child: ChatList()),
              ],
            ),
            Forum(userId: loggedInUserId),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.redAccent,
          onPressed: () => _startPublicConsultation(context),
          child: const Icon(Icons.videocam, color: Colors.white),
          tooltip: 'Start Public Consultation',
        ),
      ),
    );
  }
}
