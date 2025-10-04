import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

import '../Services/forum_firebase_service.dart';

class CreatePostDialog extends StatefulWidget {
  final String userId;

  const CreatePostDialog({required this.userId});

  @override
  _CreatePostDialogState createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final TextEditingController _contentController = TextEditingController();
  String? _imageUrl;
  String? _videoUrl;
  File? _localImageFile;
  File? _localVideoFile;
  VideoPlayerController? _videoPlayerController;
  bool _isLoading = false;

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _localImageFile = File(pickedFile.path);
        _isLoading = true;
      });

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref =
      FirebaseStorage.instance.ref().child('post_images/$fileName');
      UploadTask uploadTask = ref.putFile(File(pickedFile.path));
      TaskSnapshot snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _localVideoFile = File(pickedFile.path);
        _isLoading = true;
      });

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref =
      FirebaseStorage.instance.ref().child('post_videos/$fileName');
      UploadTask uploadTask = ref.putFile(File(pickedFile.path));
      TaskSnapshot snapshot = await uploadTask;
      _videoUrl = await snapshot.ref.getDownloadURL();

      _videoPlayerController = VideoPlayerController.file(_localVideoFile!)
        ..initialize().then((_) {
          setState(() {});
        });

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isNotEmpty ||
        _imageUrl != null ||
        _videoUrl != null) {
      await ForumFirebaseService().createPost(
        widget.userId,
        _contentController.text,
        _imageUrl,
        _videoUrl,
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              "Create Post",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Text input
            TextField(
              controller: _contentController,
              maxLines: 4,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's happening?",
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Image preview
            if (_localImageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _localImageFile!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            // Video preview if uploaded
            if (_localVideoFile != null&&
                _videoPlayerController != null &&
                _videoPlayerController!.value.isInitialized)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 150, // ✅ Constrain the height so it doesn't overflow
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: 16 / 9, // ✅ Keeps video aspect ratio
                      child: VideoPlayer(_videoPlayerController!),
                    ),
                  ),
                ),
              ),

            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),

            const SizedBox(height: 4),

            // Upload buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _uploadImage,
                  icon: Icon(Icons.image, color: Colors.white),
                  label: Text(
                    'Image',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                TextButton.icon(
                  onPressed: _uploadVideo,
                  icon: Icon(Icons.videocam, color: Colors.white),
                  label: Text(
                    'Video',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text("Post"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
