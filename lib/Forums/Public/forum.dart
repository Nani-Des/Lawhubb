import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Home/Widgets/custom_bottom_navbar.dart';
import '../../Hospital/doctor_profile.dart';
import '../Chat/live_stream.dart';
import 'Services/forum_firebase_service.dart';
import 'Widgets/create_post_dialog.dart';
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
  String? _userProfileImageUrl;

  @override
  void initState() {
    super.initState();
    debugPrint('Forum Page Initialized with userId: ${widget.userId}');
    _loadPosts();
    _loadUserProfile();
  }

  Future<void> _loadPosts() async {
    List<Map<String, dynamic>> posts = await _firebaseService.fetchPosts();
    setState(() {
      _posts = posts;
    });
  }

  Future<void> _loadUserProfile() async {
    if (widget.userId.isEmpty) {
      debugPrint('User ID is empty');
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userProfileImageUrl = userDoc['User Pic'] ?? '';
      });
    }
  }

  void _createPost() {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(userId: widget.userId),
    ).then((_) => _loadPosts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: _posts.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No posts yet. Be the first to share!',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadPosts,
        color: Colors.black87,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          itemCount: _posts.length + 1,
          itemBuilder: (context, index) {
            // 🔹 Add Live Section Header
            if (index == 0) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),

                // ✅ Decorative background added here
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF212121),
                      Color(0xFF424242),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),

                child: Column(
                  children: [
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
                              final initiatorId =
                              consult['initiatorId'];

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
                                        child:
                                        CircularProgressIndicator(
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
                                                      : Colors
                                                      .redAccent,
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(10),
                                                ),
                                                child: Text(
                                                  isHost
                                                      ? "YOU"
                                                      : "LIVE",
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: PostCard(
                postData: post,
                refreshCallback: _loadPosts,
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        backgroundColor: Colors.redAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,


    );
  }
}
