import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Home/Widgets/custom_bottom_navbar.dart';
import '../../Hospital/doctor_profile.dart';
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
      backgroundColor: Colors.grey[100], // Light grey background for contrast
      //
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
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: PostCard(
                postData: _posts[index],
                refreshCallback: _loadPosts,
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        backgroundColor: Colors.redAccent, // Dark button for contrast
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Rounded square shape
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
    );
  }
}