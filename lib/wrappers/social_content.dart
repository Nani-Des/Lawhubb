import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Forums/Chat/search_screen.dart';
import '../Hospital/doctor_profile.dart';
import '../Forums/Public/forum.dart';
import '../Forums/Public/Widgets/create_post_dialog.dart';
import '../Forums/Chat/chat_list.dart';
import '../Forums/Chat/live_stream.dart';
import '../Auth/auth_screen.dart';

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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.white54,
                ),
                const SizedBox(height: 24),
                const Text(
                  'You are not logged in',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please log in to access your chats and posts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go to Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        title: SocialHubbTabBar(
          tabController: _tabController,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatList(),
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
                  builder: (context) => CreatePostDialog(userId: loggedInUserId),
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
      ),
    );
  }
}

class SocialHubbTabBar extends StatelessWidget {
  final TabController tabController;

  const SocialHubbTabBar({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 280,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: tabController.index == 0 ? 4 : 144,
                      top: 4,
                      child: Container(
                        width: 132,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => tabController.animateTo(0),
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_rounded,
                                      size: 18,
                                      color: tabController.index == 0
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Chats',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: tabController.index == 0
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: tabController.index == 0
                                            ? Colors.white
                                            : Colors.white70,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => tabController.animateTo(1),
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.forum_rounded,
                                      size: 18,
                                      color: tabController.index == 1
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Posts',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: tabController.index == 1
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: tabController.index == 1
                                            ? Colors.white
                                            : Colors.white70,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
