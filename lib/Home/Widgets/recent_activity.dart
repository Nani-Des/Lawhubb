import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/l10n/app_localizations.dart';
import '../../Services/recent_activity_service.dart';
import '../../booking_page.dart';
import '../../utils/app_navigation.dart';
import '../../Library/library_book_gate.dart';
import '../../Library/library_page.dart';
import '../../Forums/Chat/chat_screen.dart';
import 'package:hive/hive.dart';

class RecentActivity extends StatefulWidget {
  final Function(int)? onTabChange;

  const RecentActivity({
    super.key,
    this.onTabChange,
  });

  @override
  State<RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<RecentActivity>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final RecentActivityService _activityService = RecentActivityService();
  List<ActivityItem> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final activities = await _activityService.getRecentActivities(user.uid, limit: 5);
      setState(() {
        _activities = activities;
        _isLoading = false;
      });

      // Generate animations for loaded activities
      _controller.reset();
      _controller.forward();
    } catch (e) {
      debugPrint('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Animation<Offset>> _getSlideAnimations(int count) {
    return List.generate(count, (index) {
      final start = index * 0.15;
      final end = (0.6 + (index * 0.15)).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          end,
          curve: Curves.easeOutCubic,
        ),
      ));
    });
  }

  IconData _getIconForType(ActivityType type) {
    switch (type) {
      case ActivityType.booking:
        return Icons.calendar_today_outlined;
      case ActivityType.message:
        return Icons.message_outlined;
      case ActivityType.documentSaved:
        return Icons.bookmark_outline;
      case ActivityType.readingHistory:
        return Icons.menu_book_outlined;
    }
  }

  Future<void> _handleActivityTap(ActivityItem activity) async {
    switch (activity.type) {
      case ActivityType.booking:
        if (activity.id != null) {
          pushAppRoute(
            context,
            BookingPage(currentUserId: activity.id!),
          );
        }
        break;
      case ActivityType.message:
        if (activity.metadata != null) {
          final chatId = activity.metadata!['chatId'];
          final senderId = activity.metadata!['senderId'];
          final senderName = activity.metadata!['senderName'] ?? 'User';
          final senderPic = activity.metadata!['senderPic'] ?? '';
          final senderRole = activity.metadata!['senderRole'] ?? false;
          if (chatId != null && senderId != null) {
            pushAppRoute(
              context,
              ChatScreen(
                chatId: chatId,
                recipientId: senderId,
                recipientName: senderName,
                recipientPic: senderPic,
                recipientRole: senderRole,
              ),
            );
          }
        }
        break;
      case ActivityType.documentSaved:
      case ActivityType.readingHistory:
        if (activity.metadata != null) {
          final documentId = activity.metadata!['documentId'];
          if (documentId != null) {
            try {
              final archiveBox = await Hive.openBox('reading_archive');
              final docData = archiveBox.get(documentId);
              if (docData is Map && docData['url'] != null) {
                final map = Map<String, dynamic>.from(docData);
                await openLibraryBookReader(
                  context,
                  {
                    'id': documentId.toString(),
                    ...map,
                  },
                  initialPage: map['progressPage'] as int?,
                );
              } else {
                // Navigate to library to find the document
                pushAppRoute(context, const LibraryPage());
              }
            } catch (e) {
              pushAppRoute(context, const LibraryPage());
            }
          } else {
            pushAppRoute(context, const LibraryPage());
          }
        } else {
          pushAppRoute(context, const LibraryPage());
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              localizations?.recentActivity ?? 'Recent Activity',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[800]!,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    if (_activities.isEmpty) {
      return const SizedBox.shrink();
    }

    final animations = _getSlideAnimations(_activities.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations?.recentActivity ?? 'Recent Activity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ...List.generate(_activities.length, (index) {
                  final activity = _activities[index];
                  final widgetList = <Widget>[];
                  
                  if (index > 0) {
                    widgetList.add(_buildDivider());
                  }

                  widgetList.add(
                    SlideTransition(
                      position: animations[index],
                      child: _ActivityItem(
                        icon: _getIconForType(activity.type),
                        title: activity.title,
                        subtitle: activity.subtitle,
                        time: _activityService.getTimeAgo(activity),
                        onTap: () => _handleActivityTap(activity),
                      ),
                    ),
                  );

                  return Column(children: widgetList);
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey[850],
    );
  }
}

class _ActivityItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback? onTap;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.onTap,
  });

  @override
  State<_ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<_ActivityItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.grey[850] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.time,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
