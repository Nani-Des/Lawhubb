import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../Hospital/doctor_profile.dart';
import '../../ChatModule/chat_module.dart';
import 'Services/law_insights_service.dart';
import 'Widgets/insight_video_player.dart';
import 'insight_detail_page.dart';
import 'edit_insight_dialog.dart';

class InsightCard extends StatefulWidget {
  final String insightId;
  final Map<String, dynamic> insightData;

  const InsightCard({
    required this.insightId,
    required this.insightData,
    super.key,
  });

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard>
    with SingleTickerProviderStateMixin {
  final LawInsightsService _service = LawInsightsService();
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;
  bool _isDescriptionExpanded = false;
  Map<String, dynamic>? _userData;
  bool _hasViewed = false;
  bool _isDeleting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _incrementView();
  }

  Future<void> _loadUserData() async {
    final userId = widget.insightData['userId'] as String?;
    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userData = userDoc.data();
        });
      }
    }
  }

  Future<void> _incrementView() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Check if user has already viewed this insight
    final viewedBy = List<String>.from(widget.insightData['viewedBy'] ?? []);
    if (viewedBy.contains(userId)) {
      _hasViewed = true;
      return;
    }

    if (!_hasViewed) {
      _hasViewed = true;
      await _service.incrementViews(widget.insightId, userId);
    }
  }

  Future<void> _toggleLike() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like insights')),
      );
      return;
    }

    // Optimistic update
    setState(() {});
    await _service.toggleLike(widget.insightId, userId);
  }

  Future<void> _addComment() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    // Word filter check
    final canPost = await WordFilterService().canSendMessage(comment, context);
    if (!canPost) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    await _service.addComment(
      insightId: widget.insightId,
      userId: userId,
      userName: '${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}'.trim(),
      userPic: userData['User Pic'] ?? '',
      comment: comment,
    );

    _commentController.clear();
  }

  void _shareInsight() {
    final title = widget.insightData['title'] ?? '';
    final description = widget.insightData['description'] ?? '';
    final videoUrl = widget.insightData['videoUrl'] as String? ?? '';

    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.writeln(title);
      buffer.writeln();
    }
    if (description.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }
    if (videoUrl.isNotEmpty) {
      buffer.writeln('🎥 Watch: $videoUrl');
    }
    buffer.writeln('\nShared from LawHubb');

    Share.share(buffer.toString().trim());
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _editInsight() async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditInsightDialog(
        insightId: widget.insightId,
        insightData: widget.insightData,
      ),
    );
    if (result == true && mounted) {
      // Refresh is handled by the stream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insight updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteInsight() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Insight',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this insight? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await _service.deleteInsight(widget.insightId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Insight deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting insight: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final insightUserId = widget.insightData['userId'] as String?;
    final isAuthor = userId != null && userId == insightUserId;
    final likedBy = List<String>.from(widget.insightData['likedBy'] ?? []);
    final isLiked = userId != null && likedBy.contains(userId);
    final views = widget.insightData['views'] ?? 0;
    final commentsCount = widget.insightData['commentsCount'] ?? 0;
    final likes = widget.insightData['likes'] ?? 0;
    final videoUrl = widget.insightData['videoUrl'] as String? ?? '';
    final createdAt = widget.insightData['createdAt'] as Timestamp?;

    if (_isDeleting) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final userId = widget.insightData['userId'] as String?;
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorProfileScreen(
                            userId: userId,
                            isReferral: false,
                          ),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _userData?['User Pic'] != null &&
                            (_userData!['User Pic'] as String).isNotEmpty
                        ? NetworkImage(_userData!['User Pic'] as String)
                        : null,
                    child: _userData?['User Pic'] == null ||
                            (_userData!['User Pic'] as String).isEmpty
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final userId = widget.insightData['userId'] as String?;
                      if (userId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorProfileScreen(
                              userId: userId,
                              isReferral: false,
                            ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_userData?['Fname'] ?? ''} ${_userData?['Lname'] ?? ''}'
                              .trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.insightData['category'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Action buttons (edit/delete for author, share for all)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white, size: 20),
                      onPressed: _shareInsight,
                    ),
                    if (isAuthor)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: Colors.white, size: 20),
                        color: Colors.grey[900],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editInsight();
                          } else if (value == 'delete') {
                            _deleteInsight();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Edit',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.insightData['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _ExpandableDescription(
                  description:
                      widget.insightData['description'] as String? ?? '',
                  isExpanded: _isDescriptionExpanded,
                  onToggle: () => setState(
                      () => _isDescriptionExpanded = !_isDescriptionExpanded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Video
          if (videoUrl.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InsightDetailPage(
                      insightId: widget.insightId,
                      insightData: widget.insightData,
                    ),
                  ),
                );
              },
              child: InsightVideoPlayer(videoUrl: videoUrl),
            ),
          // Metrics & Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _MetricChip(
                      icon: Icons.visibility,
                      count: views,
                      label: 'views',
                    ),
                    const SizedBox(width: 16),
                    _MetricChip(
                      icon: Icons.comment,
                      count: commentsCount,
                      label: 'comments',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleLike,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      key: ValueKey(isLiked),
                                      color: isLiked ? Colors.red : Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$likes',
                                    style: TextStyle(
                                      color: isLiked ? Colors.red : Colors.grey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() => _showComments = !_showComments);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _showComments
                                  ? Colors.grey[700]
                                  : Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _showComments
                                      ? Icons.comment
                                      : Icons.comment_outlined,
                                  color: _showComments
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$commentsCount',
                                  style: TextStyle(
                                    color: _showComments
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Comments section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showComments
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: _service.getCommentsStream(widget.insightId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox();
                            }
                            final comments = snapshot.data!.docs;
                            if (comments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No comments yet',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                              );
                            }
                            return Column(
                              children: comments.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return _CommentItem(commentData: data);
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide:
                                        BorderSide(color: Colors.grey[700]!),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _addComment,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ExpandableDescription extends StatelessWidget {
  final String description;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ExpandableDescription({
    required this.description,
    required this.isExpanded,
    required this.onToggle,
  });

  // ~60 chars per line at 14 px on a typical phone — 3 lines ≈ 180 chars.
  static const int _threshold = 180;

  @override
  Widget build(BuildContext context) {
    final needsToggle = description.length > _threshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: TextStyle(color: Colors.grey[300], fontSize: 14),
          maxLines: isExpanded ? null : 3,
          overflow:
              isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (needsToggle) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              isExpanded ? 'less' : 'more',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _MetricChip({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> commentData;

  const _CommentItem({required this.commentData});

  @override
  Widget build(BuildContext context) {
    final userName = commentData['userName'] ?? 'Anonymous';
    final userPic = commentData['userPic'] as String? ?? '';
    final comment = commentData['comment'] ?? '';
    final createdAt = commentData['createdAt'] as Timestamp?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            backgroundImage: userPic.isNotEmpty ? NetworkImage(userPic) : null,
            child: userPic.isEmpty
                ? const Icon(Icons.person, color: Colors.grey, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 13,
                  ),
                ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
