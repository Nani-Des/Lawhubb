import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Services/follow_service.dart';
import 'user_profile_screen.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../utils/user_facing_errors.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final bool isFollowersList; // true for followers, false for following

  const FollowersListScreen({
    Key? key,
    required this.userId,
    this.isFollowersList = true,
  }) : super(key: key);

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  final FollowService _followService = FollowService();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isFollowersList ? 'Followers' : 'Following',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.isFollowersList
            ? FirebaseFirestore.instance
                .collection('Follows')
                .doc(widget.userId)
                .collection('followers')
                .snapshots()
            : FirebaseFirestore.instance
                .collection('Follows')
                .doc(widget.userId)
                .collection('following')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isFollowersList ? Icons.people_outline : Icons.person_outline,
                    size: 64,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isFollowersList
                        ? 'No followers yet'
                        : 'Not following anyone yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final userIds = snapshot.data!.docs.map((doc) => doc.id).toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              final targetUserId = userIds[index];
              final isOwnProfile = currentUserId == widget.userId;
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('Users')
                    .doc(targetUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final firstName = userData['Fname'] ?? '';
                  final lastName = userData['Lname'] ?? '';
                  final fullName = '$firstName $lastName'.trim();
                  final userPic = userData['User Pic'] ?? '';

                  return FutureBuilder<bool>(
                    future: currentUserId != null && currentUserId != targetUserId
                        ? _followService.isFollowing(currentUserId!, targetUserId)
                        : Future.value(false),
                    builder: (context, followSnapshot) {
                      final isFollowing = followSnapshot.data ?? false;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[900]!,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      userId: targetUserId,
                                    ),
                                  ),
                                );
                              },
                              child: ProfileAvatar.circle(
                                imageUrl: userPic,
                                radius: 24,
                                backgroundColor: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserProfileScreen(
                                        userId: targetUserId,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  fullName.isNotEmpty ? fullName : 'Anonymous',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                            // Show follow/unfollow button only if:
                            // 1. Not viewing own profile, OR
                            // 2. Viewing own profile and it's the "Following" list (so you can unfollow)
                            if (currentUserId != null &&
                                targetUserId != currentUserId &&
                                (isOwnProfile || !isOwnProfile)) ...[
                              FutureBuilder<bool>(
                                future: _followService.isFollowing(currentUserId!, targetUserId),
                                builder: (context, snapshot) {
                                  final isCurrentlyFollowing = snapshot.data ?? false;
                                  return TextButton(
                                    onPressed: () async {
                                      try {
                                        if (isCurrentlyFollowing) {
                                          await _followService.unfollowUser(currentUserId!, targetUserId);
                                        } else {
                                          await _followService.followUser(currentUserId!, targetUserId);
                                        }
                                        setState(() {}); // Refresh the UI
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(UserFacingErrors.actionFailed(action: 'follow user')),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    child: Text(
                                      isCurrentlyFollowing ? 'Unfollow' : 'Follow',
                                      style: TextStyle(
                                        color: isCurrentlyFollowing
                                            ? Colors.red
                                            : Colors.blue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
