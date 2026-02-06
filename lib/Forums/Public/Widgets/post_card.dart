import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Forums/Public/Widgets/postcard_media.dart';
import '../../../Hospital/doctor_profile.dart';
import '../../../Services/translation_service.dart';
import 'delete_post_service.dart';
import 'full_screen.dart';
import 'add_comment.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final Function refreshCallback;

  PostCard({required this.postData, required this.refreshCallback});

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final DeletePostService _deletePostService = DeletePostService();
  bool _isLiked = false;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Translation state variables
  String? _translatedContent;
  String? _currentTranslationLanguage;
  bool _isTranslating = false;

  Future<void> _reportPost() async {
    final TextEditingController reasonController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title:
              const Text('Report Post', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Reason for reporting...',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;

                await FirebaseFirestore.instance.collection('Reports').add({
                  'postId': widget.postData['id'],
                  'reporterId': currentUserId,
                  'reportedUserId': widget.postData['User ID'],
                  'reason': reasonController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Report submitted. Thank you for keeping our community safe.')),
                  );
                }
              },
              child: const Text('Submit',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _blockUser() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Block User?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will no longer see posts or comments from this user.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (currentUserId == null) return;

              await FirebaseFirestore.instance
                  .collection('UserBlocks')
                  .doc(currentUserId)
                  .collection('blockedUsers')
                  .doc(widget.postData['User ID'])
                  .set({
                'blockedUserId': widget.postData['User ID'],
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked.')),
                );
                widget.refreshCallback(); // Refresh feed to remove their posts
              }
            },
            child:
                const Text('Block', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  void _checkIfLiked() async {
    String userId = 'user_id'; // replace with actual user id
    DocumentSnapshot postSnapshot = await FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postData['id'])
        .collection('Likes')
        .doc(userId)
        .get();

    setState(() {
      _isLiked = postSnapshot.exists;
    });
  }

  void _likePost() async {
    if (!_isLiked) {
      String userId = 'user_id'; // replace with actual user id
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postData['id'])
          .collection('Likes')
          .doc(userId)
          .set({'User ID': userId});

      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postData['id'])
          .update({'Likes': widget.postData['Likes'] + 1});

      setState(() {
        _isLiked = true;
        widget.postData['Likes'] += 1;
      });
    }
  }

  Future<Map<String, String?>> _fetchUserDetails(String userId) async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    String? userImageUrl = userDoc['User Pic'];
    String? userFullName = '${userDoc['Fname']} ${userDoc['Lname']}';
    return {'imageUrl': userImageUrl, 'fullName': userFullName};
  }

  void _viewImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  void _viewComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCommentScreen(postId: widget.postData['id']),
    );
  }

  void _onLongPressPost() {
    _deletePostService.deletePost(context, widget.postData['id']).then((_) {
      widget.refreshCallback();
    });
  }

  Future<void> _showTranslationOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Translate to',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...['English', 'Spanish', 'French'].map((language) {
              final languageCode = TranslationService.getLanguageCode(language);
              final isCurrentLanguage =
                  _currentTranslationLanguage == languageCode;

              return ListTile(
                leading: Icon(
                  isCurrentLanguage
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: isCurrentLanguage ? Colors.greenAccent : Colors.grey,
                ),
                title: Text(
                  language,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: isCurrentLanguage
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _translateContent(languageCode);
                      },
              );
            }),
            if (_translatedContent != null)
              Column(
                children: [
                  const Divider(color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Colors.blue),
                    title: const Text(
                      'View Original',
                      style: TextStyle(color: Colors.blue),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _translatedContent = null;
                        _currentTranslationLanguage = null;
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _translateContent(String targetLanguageCode) async {
    if (widget.postData['Content'] == null ||
        widget.postData['Content'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No content to translate')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final translatedText = await TranslationService.translateText(
        widget.postData['Content'],
        targetLanguageCode,
      );

      if (mounted) {
        setState(() {
          _translatedContent = translatedText;
          _currentTranslationLanguage = targetLanguageCode;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
              color: Colors.grey[900]!, width: 1), // Minimal separator
        ),
      ),
      child: GestureDetector(
        onLongPress: _onLongPressPost,
        onTap: _viewComments,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            FutureBuilder<Map<String, String?>>(
              future: _fetchUserDetails(widget.postData['User ID']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.grey)),
                  );
                }
                if (snapshot.hasError) {
                  return const SizedBox.shrink();
                }

                var userDetails = snapshot.data!;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onTap: () async {
                    DocumentSnapshot userDoc = await FirebaseFirestore.instance
                        .collection('Users')
                        .doc(widget.postData['User ID'])
                        .get();

                    if (userDoc.exists && userDoc['Role'] == true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorProfileScreen(
                              userId: widget.postData['User ID'],
                              isReferral: false),
                        ),
                      );
                    }
                  },
                  leading: CircleAvatar(
                    backgroundImage:
                        NetworkImage(userDetails['imageUrl'] ?? ''),
                    radius: 18, // Slightly smaller for modern look
                    backgroundColor: Colors.grey[800],
                  ),
                  title: Text(
                    userDetails['fullName'] ?? 'Anonymous',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    color: Colors.grey[900],
                    onSelected: (value) {
                      if (value == 'block') {
                        _blockUser();
                      } else if (value == 'report') {
                        _reportPost();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      if (widget.postData['User ID'] != currentUserId) ...[
                        const PopupMenuItem<String>(
                          value: 'report',
                          child: Text('Report Post',
                              style: TextStyle(color: Colors.white)),
                        ),
                        const PopupMenuItem<String>(
                          value: 'block',
                          child: Text('Block User',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ] else
                        const PopupMenuItem<String>(
                          enabled: false,
                          value: 'none',
                          child: Text('Your Post',
                              style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                );
              },
            ),

            // Content Text
            if (widget.postData['Content'] != null &&
                widget.postData['Content'].isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Original or Translated Content
                    if (_isTranslating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    else
                      Text(
                        _translatedContent ?? widget.postData['Content'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    // Translation Language Badge
                    if (_currentTranslationLanguage != null && !_isTranslating)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Translated to ${TranslationService.getLanguageName(_currentTranslationLanguage!)}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Translation Button
            if (widget.postData['Content'] != null &&
                widget.postData['Content'].isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: GestureDetector(
                  onTap: _showTranslationOptions,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _translatedContent != null
                            ? 'Change Translation'
                            : 'Translate',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Video
            if (widget.postData['VideoURL'] != null)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 400),
                color: Colors.black,
                child: VideoPlayerWidget(videoUrl: widget.postData['VideoURL']),
              )

            // Image
            else if (widget.postData['ImageURL'] != null)
              GestureDetector(
                onTap: () => _viewImage(widget.postData['ImageURL']),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 400),
                  color: Colors.grey[900],
                  child: Image.network(
                    widget.postData['ImageURL'],
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Action Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
              child: Row(
                children: [
                  // Like Button
                  InkWell(
                    onTap: _likePost,
                    child: Row(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.redAccent : Colors.white,
                          size: 22, // Standard size
                        ),
                        if (widget.postData['Likes'] > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${widget.postData['Likes']}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Comment Button
                  InkWell(
                    onTap: _viewComments,
                    child: const Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 22),
                  ),

                  const Spacer(),

                  // Share/Other (Optional, using report for now as placeholder for consistency)
                  // InkWell(
                  //   onTap: () {},
                  //   child: Icon(Icons.share_outlined, color: Colors.white, size: 22),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
