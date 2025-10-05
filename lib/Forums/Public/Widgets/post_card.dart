import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/Forums/Public/Widgets/postcard_media.dart';
import 'package:video_player/video_player.dart';
import '../../../Hospital/doctor_profile.dart';
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
  final double _fontSize = 10.0;
  bool _isLiked = false;

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

  String _truncateContent(String content, int wordLimit) {
    List<String> words = content.split(' ');
    if (words.length > wordLimit) {
      return words.sublist(0, wordLimit).join(' ') + '...';
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(4.0),
      color: Colors.black87,
      child: GestureDetector(
        onLongPress: _onLongPressPost,
        onTap: _viewComments,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, String?>>(
              future: _fetchUserDetails(widget.postData['User ID']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var userDetails = snapshot.data!;
                return GestureDetector(
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
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('This user is not a doctor.')),
                      );
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                      NetworkImage(userDetails['imageUrl'] ?? ''),
                      radius: 20,
                    ),
                    title: Text(
                      userDetails['fullName'] ?? 'Anonymous',
                      style:
                      TextStyle(color: Colors.white, fontSize: _fontSize),
                    ),
                  ),
                );
              },
            ),

            if (widget.postData['Content'] != null &&
                widget.postData['Content'].isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                child: Text(
                  _truncateContent(widget.postData['Content'], 15),
                  style: TextStyle(color: Colors.white, fontSize: _fontSize),
                ),
              ),

            // Video
            if (widget.postData['VideoURL'] != null)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    width: double.infinity, // take full width like images
                    constraints: BoxConstraints(
                      maxHeight: 250, // prevent overflow but allow flexibility
                    ),
                    color: Colors.black, // background for letterboxing
                    child: Center(
                      child: VideoPlayerWidget(videoUrl: widget.postData['VideoURL']),
                    ),
                  ),
                ),
              )

// Image
            else if (widget.postData['ImageURL'] != null)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: GestureDetector(
                  onTap: () => _viewImage(widget.postData['ImageURL']),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.grey[800],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        widget.postData['ImageURL'],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.thumb_up,
                          color: _isLiked ? Colors.redAccent : Colors.white,
                          size: 12,
                        ),
                        onPressed: _likePost,
                      ),
                      Text(
                        '${widget.postData['Likes']}',
                        style:
                        TextStyle(color: Colors.white, fontSize: _fontSize),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.comment, color: Colors.white, size: 12),
                    onPressed: _viewComments,
                  ),
                  IconButton(
                    icon: Icon(Icons.report, color: Colors.white, size: 12),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


