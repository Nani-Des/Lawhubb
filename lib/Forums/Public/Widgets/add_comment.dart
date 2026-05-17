import 'package:flutter/material.dart';
import '../../../widgets/profile_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../ChatModule/chat_module.dart';

class AddCommentScreen extends StatefulWidget {
  final String postId;

  const AddCommentScreen({required this.postId, Key? key}) : super(key: key);

  @override
  _AddCommentScreenState createState() => _AddCommentScreenState();
}

class _AddCommentScreenState extends State<AddCommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  String? currentUserId;
  String? currentUserPic;
  Map<String, bool> _expandedReplies = {};

  // reply state
  String? replyingToCommentId;
  String? replyingToUserName;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchCurrentUserPic();
  }

  Future<void> _fetchCurrentUserPic() async {
    if (currentUserId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUserId)
          .get();
      setState(() {
        currentUserPic = userDoc['User Pic'];
      });
    }
  }

  Future<Map<String, String?>> _fetchUserDetails(String userId) async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    return {
      'imageUrl': userDoc['User Pic'],
      'fullName': '${userDoc['Fname']} ${userDoc['Lname']}'
    };
  }

  void _sendCommentOrReply() async {
    if (currentUserId == null || _commentController.text.isEmpty) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Word filter check
    final canPost = await WordFilterService().canSendMessage(text, context);
    if (!canPost) return;

    if (replyingToCommentId != null) {
      // store reply
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId)
          .collection('Comments')
          .doc(replyingToCommentId)
          .collection('Replies')
          .add({
        'Content': text,
        'Timestamp': FieldValue.serverTimestamp(),
        'User ID': currentUserId,
      });
    } else {
      // store main comment
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId)
          .collection('Comments')
          .add({
        'Content': text,
        'Timestamp': FieldValue.serverTimestamp(),
        'User ID': currentUserId,
      });
    }

    setState(() {
      replyingToCommentId = null;
      replyingToUserName = null;
    });
    _commentController.clear();
  }

  Future<void> _toggleLike(DocumentReference itemRef) async {
    if (currentUserId == null) return;
    final likeRef = itemRef.collection('Likes').doc(currentUserId);

    if ((await likeRef.get()).exists) {
      await likeRef.delete();
    } else {
      await likeRef.set({'User ID': currentUserId});
    }
  }

  /// ---------- Replies ----------
  Widget _buildReplies(String commentId) {
    final replyPath = FirebaseFirestore.instance.collection(
        'Posts/${widget.postId}/Comments/$commentId/Replies'
            .replaceAll('//', '/'));

    return StreamBuilder<QuerySnapshot>(
      stream: replyPath.orderBy('Timestamp').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();

        final replies = snapshot.data!.docs;

        if (_expandedReplies[commentId] != true) {
          return GestureDetector(
            onTap: () => setState(() => _expandedReplies[commentId] = true),
            child: Padding(
              padding: const EdgeInsets.only(left: 60, top: 6),
              child: Text(
                "View ${replies.length} more replies",
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...replies.map((replyDoc) {
              final reply = replyDoc.data() as Map<String, dynamic>;
              final replyId = replyDoc.id;
              final replyRef = replyDoc.reference;

              return FutureBuilder<Map<String, String?>>(
                future: _fetchUserDetails(reply['User ID']),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 50, top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileAvatar.circle(
                          imageUrl: snap.data?['imageUrl']?.toString(),
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  children: [
                                    TextSpan(
                                        text: "${snap.data?['fullName']} ",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(text: reply['Content'] ?? ''),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              StreamBuilder<QuerySnapshot>(
                                stream:
                                    replyRef.collection('Likes').snapshots(),
                                builder: (context, likeSnap) {
                                  final isLiked = likeSnap.data?.docs.any(
                                          (doc) => doc.id == currentUserId) ??
                                      false;
                                  final likeCount =
                                      likeSnap.data?.docs.length ?? 0;
                                  return Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isLiked
                                              ? Colors.red
                                              : Colors.grey[400],
                                          size: 16,
                                        ),
                                        onPressed: () => _toggleLike(replyRef),
                                      ),
                                      if (likeCount > 0)
                                        Text("$likeCount",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
            GestureDetector(
              onTap: () => setState(() => _expandedReplies[commentId] = false),
              child: Padding(
                padding: const EdgeInsets.only(left: 60, top: 4),
                child: Text("Hide replies",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ---------- Comments ----------
  Widget _buildCommentItem(DocumentSnapshot commentDoc) {
    final comment = commentDoc.data() as Map<String, dynamic>;
    final commentId = commentDoc.id;
    final commentRef = commentDoc.reference;

    return FutureBuilder<Map<String, String?>>(
      future: _fetchUserDetails(comment['User ID']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar.circle(
                imageUrl: snapshot.data?['imageUrl']?.toString(),
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        children: [
                          TextSpan(
                              text: "${snapshot.data?['fullName']} ",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: comment['Content'] ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<QuerySnapshot>(
                      stream: commentRef.collection('Likes').snapshots(),
                      builder: (context, likeSnap) {
                        final isLiked = likeSnap.data?.docs
                                .any((doc) => doc.id == currentUserId) ??
                            false;
                        final likeCount = likeSnap.data?.docs.length ?? 0;
                        return Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.grey[400],
                                size: 18,
                              ),
                              onPressed: () => _toggleLike(commentRef),
                            ),
                            if (likeCount > 0)
                              Text("$likeCount",
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  replyingToCommentId = commentId;
                                  replyingToUserName =
                                      snapshot.data?['fullName'];
                                });
                              },
                              child: const Text("Reply",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildReplies(commentId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Posts')
                      .doc(widget.postId)
                      .collection('Comments')
                      .orderBy('Timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No comments yet",
                            style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return ListView(
                      controller: controller,
                      children:
                          snapshot.data!.docs.map(_buildCommentItem).toList(),
                    );
                  },
                ),
              ),

              // Input bar
              SafeArea(
                child: Container(
                  color: Colors.grey[900],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      ProfileAvatar.circle(
                        imageUrl: currentUserPic,
                        radius: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: replyingToUserName != null
                                ? "Replying to $replyingToUserName..."
                                : "Add a comment...",
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            filled: true,
                            fillColor: Colors.grey[850],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendCommentOrReply,
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
