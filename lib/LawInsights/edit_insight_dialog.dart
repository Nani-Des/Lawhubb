import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'Services/law_insights_service.dart';

class EditInsightDialog extends StatefulWidget {
  final String insightId;
  final Map<String, dynamic> insightData;

  const EditInsightDialog({
    required this.insightId,
    required this.insightData,
    super.key,
  });

  @override
  State<EditInsightDialog> createState() => _EditInsightDialogState();
}

class _EditInsightDialogState extends State<EditInsightDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final LawInsightsService _service = LawInsightsService();

  String _selectedCategory = 'Legal Topics';
  File? _newVideoFile;
  VideoPlayerController? _videoController;
  String? _currentVideoUrl;
  bool _isUploading = false;
  bool _isLoadingVideo = false;

  final List<String> _categories = [
    'Legal Topics',
    'Cases',
    'Legal Issues',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with existing data
    _titleController.text = widget.insightData['title'] ?? '';
    _descriptionController.text = widget.insightData['description'] ?? '';
    _selectedCategory = widget.insightData['category'] ?? 'Legal Topics';
    _currentVideoUrl = widget.insightData['videoUrl'] as String? ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final sizeInBytes = await file.length();
        final sizeInMb = sizeInBytes / (1024 * 1024);

        if (sizeInMb > 100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video too large. Max size is 100MB.')),
            );
          }
          return;
        }

        setState(() {
          _newVideoFile = file;
          _isLoadingVideo = true;
        });

        _videoController?.dispose();
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isLoadingVideo = false;
              });
            }
          });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<String?> _uploadVideo() async {
    if (_newVideoFile == null) return _currentVideoUrl;

    setState(() => _isUploading = true);

    try {
      final fileName = 'insight_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = FirebaseStorage.instance.ref().child('law_insights/videos/$fileName');

      final uploadTask = ref.putFile(_newVideoFile!);
      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();

      setState(() => _isUploading = false);
      return videoUrl;
    } catch (e) {
      setState(() => _isUploading = false);
      throw e;
    }
  }

  Future<void> _updateInsight() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? videoUrl = _currentVideoUrl;
      if (_newVideoFile != null) {
        videoUrl = await _uploadVideo();
      }

      await _service.updateInsight(
        insightId: widget.insightId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        videoUrl: videoUrl,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insight updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating insight: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Edit Insight',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[800]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[800]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Category
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[800]!),
                          ),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value!);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Video preview/edit
                      if (_currentVideoUrl != null && _currentVideoUrl!.isNotEmpty && _newVideoFile == null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.video_library, color: Colors.grey, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Current video will be replaced',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: _pickVideo,
                                child: const Text('Change Video', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      else if (_newVideoFile != null)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                _isLoadingVideo
                                    ? const Center(child: CircularProgressIndicator())
                                    : _videoController != null &&
                                            _videoController!.value.isInitialized
                                        ? AspectRatio(
                                            aspectRatio: _videoController!.value.aspectRatio,
                                            child: VideoPlayer(_videoController!),
                                          )
                                        : const SizedBox(),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _newVideoFile = null;
                                        _videoController?.dispose();
                                        _videoController = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _pickVideo,
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.video_library, color: Colors.grey, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Select New Video',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Max 100MB',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _updateInsight,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Update Insight',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}








