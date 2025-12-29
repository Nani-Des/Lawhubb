import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Chat/live_stream.dart';
import 'Services/forum_firebase_service.dart';
import 'Widgets/post_card.dart';

class Forum extends StatefulWidget {
  final String userId;

  const Forum({required this.userId, super.key});

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<Forum> {
  final ForumFirebaseService _firebaseService = ForumFirebaseService();
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    debugPrint('Forum Page Initialized with userId: ${widget.userId}');
    _loadPosts();
    _loadUserProfile();
  }

  Future<void> _loadPosts() async {
    // 1. Fetch blocked users first
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    Set<String> blockedUserIds = {};

    if (currentUserId != null) {
      try {
        final blockedSnapshot = await FirebaseFirestore.instance
            .collection('UserBlocks')
            .doc(currentUserId)
            .collection('blockedUsers')
            .get();

        blockedUserIds = blockedSnapshot.docs.map((doc) => doc.id).toSet();
      } catch (e) {
        debugPrint("Error fetching blocked users: $e");
      }
    }

    // 2. Fetch all posts
    List<Map<String, dynamic>> posts = await _firebaseService.fetchPosts();

    // 3. Filter out posts from blocked users
    if (blockedUserIds.isNotEmpty) {
      posts = posts.where((post) {
        final postUserId = post['User ID'];
        return !blockedUserIds.contains(postUserId);
      }).toList();
    }

    setState(() {
      _posts = posts;
    });
  }

  Future<void> _loadUserProfile() async {
    if (widget.userId.isEmpty) {
      debugPrint('User ID is empty');
      return;
    }
    // User profile loading logic if needed for header
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Modern minimalistic black background

      body: _posts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined,
                      size: 60, color: Colors.white24), // Subtle icon
                  SizedBox(height: 16),
                  Text(
                    'No posts yet.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Be the first to share something.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPosts,
              color: Colors.white, // White loading indicator
              backgroundColor: Colors.grey[900],
              child: ListView.builder(
                padding: EdgeInsets
                    .zero, // Remove default padding for edge-to-edge look
                itemCount: _posts.length + 1,
                itemBuilder: (context, index) {
                  // 🔹 Live Section Header
                  if (index == 0) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.only(
                          bottom: 0), // Seamless transition

                      // Minimalistic dark gradient
                      decoration: BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Colors.grey[900]!, width: 1)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.grey[900]!,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 16.0, bottom: 12.0),
                            child: Text(
                              "LIVE NOW",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 95,
                            child: StreamBuilder(
                              stream: FirebaseFirestore.instance
                                  .collection('Consultations')
                                  .where('status', isEqualTo: 'active')
                                  .where('recipientId', isEqualTo: 'public')
                                  .snapshots(),
                              builder: (context,
                                  AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  );
                                }

                                final consults = snapshot.data!.docs;

                                if (consults.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      "No active livestreams",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: consults.length,
                                  itemBuilder: (context, index) {
                                    final consult = consults[index];
                                    final initiatorId = consult['initiatorId'];

                                    return FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('Users')
                                          .doc(initiatorId)
                                          .get(),
                                      builder: (context, userSnap) {
                                        if (userSnap.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 80,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.white),
                                            ),
                                          );
                                        }

                                        if (!userSnap.hasData ||
                                            !userSnap.data!.exists) {
                                          return const SizedBox(
                                            width: 80,
                                            child: Center(
                                              child: Icon(
                                                Icons.person_off,
                                                size: 35,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          );
                                        }

                                        final userData = userSnap.data!.data()
                                                as Map<String, dynamic>? ??
                                            {};
                                        final fullName =
                                            "${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}"
                                                .trim();
                                        final userPic =
                                            userData['User Pic'] ?? '';
                                        final isHost =
                                            initiatorId == widget.userId;

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    LiveConsultationScreen(
                                                  channelName:
                                                      consult['chatId'],
                                                  isInitiator: isHost,
                                                  chatId: consult['chatId'],
                                                  initiatorId: initiatorId,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Column(
                                              children: [
                                                Stack(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 35,
                                                      backgroundImage:
                                                          userPic.isNotEmpty
                                                              ? NetworkImage(
                                                                  userPic)
                                                              : null,
                                                      backgroundColor:
                                                          Colors.grey[300],
                                                      child: userPic.isEmpty
                                                          ? const Icon(
                                                              Icons.person,
                                                              size: 35,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                          : null,
                                                    ),
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              bottom: 2),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isHost
                                                            ? Colors
                                                                .tealAccent[700]
                                                            : Colors.redAccent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        isHost ? "YOU" : "LIVE",
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  fullName.isNotEmpty
                                                      ? (fullName.length > 24
                                                          ? '${fullName.substring(0, 21)}...'
                                                          : fullName)
                                                      : (isHost
                                                          ? "You"
                                                          : "Host"),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
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
                        ],
                      ),
                    );
                  }

                  // 🔹 Adjust index for post list
                  final post = _posts[index - 1];
                  return PostCard(
                    postData: post,
                    refreshCallback: _loadPosts,
                  );
                },
              ),
            ),
    );
  }
}
