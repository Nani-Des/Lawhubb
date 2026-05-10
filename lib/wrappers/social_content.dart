import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Forums/Chat/search_screen.dart';
import '../Forums/Public/forum.dart';
import '../Forums/Public/Widgets/create_post_dialog.dart';
import '../Forums/Public/Widgets/user_profile_screen.dart';
import '../LawInsights/law_insights_page.dart';
import '../Forums/Chat/live_stream.dart';
import '../Auth/login_required_shell.dart';

class SocialContent extends StatefulWidget {
  final int initialTabIndex;

  const SocialContent({super.key, this.initialTabIndex = 0});

  @override
  State<SocialContent> createState() => _SocialContentState();
}

class _SocialContentState extends State<SocialContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startPublicConsultation(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please log in to start a live stream')),
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
      debugPrint('Error starting live stream: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start the live stream. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return LoginRequiredShell(
        title: 'SocialHubb',
        message: 'Sign in to use SocialHubb.',
        onAuthResolved: () => setState(() {}),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          const LawInsightsPage(),
          Forum(userId: loggedInUserId),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          if (_tabController.index == 1) {
            return FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 4,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      CreatePostDialog(userId: loggedInUserId),
                ).then((_) {
                  setState(() {});
                });
              },
              child: const Icon(Icons.add, size: 28),
            );
          } else {
            return FloatingActionButton(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () => _startPublicConsultation(context),
              child: const Icon(Icons.videocam, size: 26),
            );
          }
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
