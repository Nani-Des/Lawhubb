import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Services/follow_service.dart';
import 'post_card.dart';
import 'full_screen.dart';
import 'followers_list_screen.dart';
import '../Services/forum_firebase_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final FollowService _followService = FollowService();
  final ForumFirebaseService _forumService = ForumFirebaseService();
  late TabController _tabController;
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _replies = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
        });

        // Load follow status
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null && currentUserId != widget.userId) {
          final isFollowing = await _followService.isFollowing(
              currentUserId, widget.userId);
          setState(() {
            _isFollowing = isFollowing;
          });
        }

        // Load follower/following counts
        final followers = await _followService.getFollowerCount(widget.userId);
        final following = await _followService.getFollowingCount(widget.userId);
        setState(() {
          _followersCount = followers;
          _followingCount = following;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      // Load all posts
      final allPosts = await _forumService.fetchPosts();
      
      // Filter posts by user
      final userPosts = allPosts
          .where((post) => post['User ID'] == widget.userId)
          .toList();

      // Separate by type - Posts tab shows ALL posts, Videos/Photos are filtered views
      final posts = <Map<String, dynamic>>[];
      final videos = <Map<String, dynamic>>[];
      final photos = <Map<String, dynamic>>[];

      // Posts tab shows all posts (sorted by timestamp)
      posts.addAll(userPosts);
      posts.sort((a, b) {
        final aTime = a['Timestamp'] as Timestamp?;
        final bTime = b['Timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Newest first
      });

      // Videos and Photos are filtered views
      for (var post in userPosts) {
        final videoUrl = post['VideoURL'];
        final imageUrl = post['ImageURL'];
        
        // Check if has video
        if (videoUrl != null && videoUrl.toString().trim().isNotEmpty) {
          videos.add(post);
        } 
        // Check if has image (but no video)
        else if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
          photos.add(post);
        }
      }

      // Load replies (comments on posts)
      final replies = <Map<String, dynamic>>[];
      for (var post in allPosts) {
        try {
          final commentsSnapshot = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(post['id'])
              .collection('Comments')
              .where('User ID', isEqualTo: widget.userId)
              .get();

          for (var commentDoc in commentsSnapshot.docs) {
            final commentData = commentDoc.data() as Map<String, dynamic>;
            replies.add({
              'Content': commentData['Content'] ?? '',
              'Timestamp': commentData['Timestamp'],
              'User ID': commentData['User ID'],
              'postId': post['id'],
              'postContent': post['Content'] ?? '',
              'postImageURL': post['ImageURL'],
              'postVideoURL': post['VideoURL'],
            });
          }

          // Also check replies to comments
          final allCommentsSnapshot = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(post['id'])
              .collection('Comments')
              .get();

          for (var commentDoc in allCommentsSnapshot.docs) {
            try {
              final repliesSnapshot = await commentDoc.reference
                  .collection('Replies')
                  .where('User ID', isEqualTo: widget.userId)
                  .get();

              for (var replyDoc in repliesSnapshot.docs) {
                final replyData = replyDoc.data();
                replies.add({
                  'Content': replyData['Content'] ?? '',
                  'Timestamp': replyData['Timestamp'],
                  'User ID': replyData['User ID'],
                  'postId': post['id'],
                  'postContent': post['Content'] ?? '',
                  'postImageURL': post['ImageURL'],
                  'postVideoURL': post['VideoURL'],
                  'isReply': true,
                });
              }
            } catch (e) {
              debugPrint('Error loading nested replies: $e');
            }
          }
        } catch (e) {
          debugPrint('Error loading comments: $e');
        }
      }

      // Sort replies by timestamp
      replies.sort((a, b) {
        final aTime = a['Timestamp'] as Timestamp?;
        final bTime = b['Timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _posts = posts;
        _videos = videos;
        _photos = photos;
        _replies = replies;
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to follow users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (currentUserId == widget.userId) return;

    try {
      // Check if already following before following (prevent duplicate)
      final alreadyFollowing = await _followService.isFollowing(currentUserId, widget.userId);
      
      if (alreadyFollowing) {
        await _followService.unfollowUser(currentUserId, widget.userId);
      } else {
        await _followService.followUser(currentUserId, widget.userId);
      }

      // Refresh counts and status
      final followers = await _followService.getFollowerCount(widget.userId);
      final following = await _followService.getFollowingCount(widget.userId);
      final isFollowing = await _followService.isFollowing(
          currentUserId, widget.userId);

      setState(() {
        _isFollowing = isFollowing;
        _followersCount = followers;
        _followingCount = following;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'User not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final firstName = _userData!['Fname'] ?? '';
    final lastName = _userData!['Lname'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final userPic = _userData!['User Pic'] ?? '';
    final email = _userData!['Email'] ?? '';
    final region = _userData!['Region'] ?? '';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Profile Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture and Follow Button Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey[800]!,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey[900],
                        backgroundImage: userPic.isNotEmpty
                            ? NetworkImage(userPic)
                            : null,
                        child: userPic.isEmpty
                            ? Icon(
                                Icons.person,
                                size: 28,
                                color: Colors.grey[600],
                              )
                            : null,
                      ),
                    ),
                    const Spacer(),
                    // Follow/Edit Button
                    if (isOwnProfile)
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit profile coming soon'),
                              backgroundColor: Colors.grey,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[700]!, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isFollowing ? Colors.transparent : Colors.white,
                          foregroundColor:
                              _isFollowing ? Colors.white : Colors.black,
                          side: BorderSide(
                            color: _isFollowing
                                ? Colors.grey[700]!
                                : Colors.transparent,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          minimumSize: const Size(0, 36),
                          elevation: 0,
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // User Name
                Text(
                  fullName.isNotEmpty ? fullName : 'Anonymous',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                if (region.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        region,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Followers and Following
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowersListScreen(
                              userId: widget.userId,
                              isFollowersList: false,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            '$_followingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Following',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowersListScreen(
                              userId: widget.userId,
                              isFollowersList: true,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            '$_followersCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Followers',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[900]!,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'Replies'),
                Tab(text: 'Videos'),
                Tab(text: 'Photos'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildRepliesTab(),
                _buildVideosTab(),
                _buildPhotosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
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

    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        return PostCard(
          postData: _posts[index],
          refreshCallback: _loadPosts,
        );
      },
    );
  }

  Widget _buildRepliesTab() {
    if (_replies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.reply_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No replies yet',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _replies.length,
      itemBuilder: (context, index) {
        final reply = _replies[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[900]!, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[900],
                    backgroundImage: _userData!['User Pic'] != null &&
                            _userData!['User Pic'].toString().isNotEmpty
                        ? NetworkImage(_userData!['User Pic'])
                        : null,
                    child: _userData!['User Pic'] == null ||
                            _userData!['User Pic'].toString().isEmpty
                        ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_userData!['Fname']} ${_userData!['Lname']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Replying to',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reply['Content'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          elevation: 0,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        body: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('Posts')
                              .doc(reply['postId'])
                              .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              );
                            }
                            final postData = {
                              'id': snapshot.data!.id,
                              ...snapshot.data!.data() as Map<String, dynamic>
                            };
                            return PostCard(
                              postData: postData,
                              refreshCallback: () async {},
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.reply_outlined, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'Replying to',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reply['postContent'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (reply['postImageURL'] != null &&
                          reply['postImageURL'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            reply['postImageURL'],
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideosTab() {
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No videos yet',
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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return GestureDetector(
          onTap: () {
            // Navigate to video player
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video player coming soon')),
            );
          },
          child: Container(
            color: Colors.grey[900],
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video['VideoURL'] != null)
                  Image.network(
                    video['VideoURL'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotosTab() {
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No photos yet',
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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () {
            // Show full screen image
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenImageView(
                  imageUrl: photo['ImageURL'],
                ),
              ),
            );
          },
          child: Image.network(
            photo['ImageURL'],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[800],
                child: const Icon(
                  Icons.image,
                  color: Colors.white,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

