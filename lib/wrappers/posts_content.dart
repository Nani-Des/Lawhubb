import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Forums/Chat/search_screen.dart';
import '../Forums/Public/forum.dart';
import '../Forums/Public/Widgets/create_post_dialog.dart';
import '../Forums/Public/Widgets/user_profile_screen.dart';
import '../Forums/Chat/live_stream.dart';
import '../Auth/auth_screen.dart';

class PostsContent extends StatefulWidget {
  const PostsContent({super.key});

  @override
  State<PostsContent> createState() => _PostsContentState();
}

class _PostsContentState extends State<PostsContent> {

  Future<void> _startPublicConsultation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to start a consultation')),
          );
        }
        return;
      }
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

      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start consultation: $e')),
        );
      }
    }
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _OptionTile(
                  icon: Icons.edit_outlined,
                  title: 'Create a New Post',
                  subtitle: 'Share your thoughts with the community',
                  onTap: () {
                    Navigator.pop(context);
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      showDialog(
                        context: context,
                        builder: (context) => CreatePostDialog(userId: currentUser.uid),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _OptionTile(
                  icon: Icons.videocam_outlined,
                  title: 'Live Stream',
                  subtitle: 'Start a live consultation',
                  onTap: () {
                    Navigator.pop(context);
                    _startPublicConsultation();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Redirect to login page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      });
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    final loggedInUserId = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: const Text(
          'Posts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
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
        onPressed: _showCreateOptions,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

