import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Forums/Chat/search_screen.dart';
import '../Hospital/doctor_profile.dart';
import '../Forums/Public/forum.dart';
import '../Forums/Public/Widgets/create_post_dialog.dart';

class SocialContent extends StatefulWidget {
  final int initialTabIndex;

  const SocialContent({super.key, this.initialTabIndex = 0});

  @override
  State<SocialContent> createState() => _SocialContentState();
}

class _SocialContentState extends State<SocialContent> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final loggedInUserId = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: const Text(
          'SocialHubb',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorProfileScreen(
                      userId: loggedInUserId,
                      isReferral: false,
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
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    userPic = data?['User Pic'];
                  }
                  return CircleAvatar(
                    radius: 18,
                    backgroundImage: userPic != null && userPic.isNotEmpty
                        ? NetworkImage(userPic)
                        : const AssetImage("assets/Images/placeholder.png")
                            as ImageProvider,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Forum(userId: loggedInUserId),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CreatePostDialog(userId: loggedInUserId),
          ).then((_) {
            setState(() {});
          });
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
