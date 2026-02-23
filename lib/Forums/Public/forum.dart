import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';
import '../Chat/live_stream.dart';
import 'Services/forum_firebase_service.dart';
import 'Widgets/post_card.dart';
import '../../../Services/follow_service.dart';

class Forum extends StatefulWidget {
  final String userId;

  const Forum({required this.userId, super.key});

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<Forum> {
  final ForumFirebaseService _firebaseService = ForumFirebaseService();
  final FollowService _followService = FollowService();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

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
    Set<String> followedUserIds = {};

    if (currentUserId != null) {
      try {
        final blockedSnapshot = await FirebaseFirestore.instance
            .collection('UserBlocks')
            .doc(currentUserId)
            .collection('blockedUsers')
            .get();

        blockedUserIds = blockedSnapshot.docs.map((doc) => doc.id).toSet();

        // Fetch followed users
        followedUserIds =
            (await _followService.getFollowingList(currentUserId)).toSet();
      } catch (e) {
        debugPrint("Error fetching blocked/followed users: $e");
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

    // 4. Sort posts: followed users first, then by timestamp (newest first)
    posts.sort((a, b) {
      final aUserId = a['User ID'] as String? ?? '';
      final bUserId = b['User ID'] as String? ?? '';

      final aIsFollowed = followedUserIds.contains(aUserId);
      final bIsFollowed = followedUserIds.contains(bUserId);

      // If one is followed and the other isn't, prioritize followed
      if (aIsFollowed && !bIsFollowed) return -1;
      if (!aIsFollowed && bIsFollowed) return 1;

      // If both are followed or both aren't, sort by timestamp (newest first)
      final aTimestamp = a['Timestamp'] as Timestamp?;
      final bTimestamp = b['Timestamp'] as Timestamp?;

      if (aTimestamp == null && bTimestamp == null) return 0;
      if (aTimestamp == null) return 1;
      if (bTimestamp == null) return -1;

      return bTimestamp.compareTo(aTimestamp);
    });

    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
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

      body: _isLoading
          ? _buildShimmerLoading()
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.forum_outlined,
                          size: 60, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.noPostsYet ??
                            'No posts yet.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)?.beFirstToPost ??
                            'Be the first to share something.',
                        style: const TextStyle(
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
                    itemBuilder: (BuildContext context, int index) {
                      // 🔹 Live Section Header
                      if (index == 0) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          margin: const EdgeInsets.only(
                              bottom: 0), // Seamless transition

                          // Minimalistic dark gradient
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey[900]!, width: 1)),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, bottom: 12.0),
                                child: Text(
                                  AppLocalizations.of(context)?.liveNow ??
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
                                      return Center(
                                        child: Text(
                                          AppLocalizations.of(context)
                                                  ?.noActiveLivestreams ??
                                              "No active livestreams",
                                          style: const TextStyle(
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

                                            final userData = userSnap.data!
                                                        .data()
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10),
                                                child: Column(
                                                  children: [
                                                    Stack(
                                                      alignment: Alignment
                                                          .bottomCenter,
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
                                                                  color: Colors
                                                                      .white,
                                                                )
                                                              : null,
                                                        ),
                                                        Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  bottom: 2),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isHost
                                                                ? Colors.tealAccent[
                                                                    700]
                                                                : Colors
                                                                    .redAccent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: Text(
                                                            isHost
                                                                ? (AppLocalizations.of(
                                                                            context)
                                                                        ?.youBadge ??
                                                                    "YOU")
                                                                : (AppLocalizations.of(
                                                                            context)
                                                                        ?.liveBadge ??
                                                                    "LIVE"),
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      fullName.isNotEmpty
                                                          ? (fullName.length >
                                                                  24
                                                              ? '${fullName.substring(0, 21)}...'
                                                              : fullName)
                                                          : (isHost
                                                              ? (AppLocalizations.of(
                                                                          context)
                                                                      ?.you ??
                                                                  "You")
                                                              : (AppLocalizations.of(
                                                                          context)
                                                                      ?.host ??
                                                                  "Host")),
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

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[900]!, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: avatar + name
                Row(
                  children: [
                    const CircleAvatar(
                        radius: 18, backgroundColor: Colors.white),
                    const SizedBox(width: 12),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 20,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Content lines
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                // Image placeholder (every other post)
                if (index % 2 == 0)
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                if (index % 2 == 0) const SizedBox(height: 14),
                // Action bar
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
