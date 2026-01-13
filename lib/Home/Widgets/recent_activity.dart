import 'package:flutter/material.dart';

class RecentActivity extends StatefulWidget {
  const RecentActivity({super.key});

  @override
  State<RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<RecentActivity>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideAnimations = List.generate(3, (index) {
      return Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(
          index * 0.2,
          0.6 + (index * 0.2),
          curve: Curves.easeOutCubic,
        ),
      ));
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[800]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[400],
                      size: 10,
                    ),
                  ],
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
                SlideTransition(
                  position: _slideAnimations[0],
                  child: _ActivityItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'Consultation Scheduled',
                    subtitle: 'With Adv. Sarah Johnson - Tomorrow 2:00 PM',
                    time: '2 hours ago',
                  ),
                ),
                _buildDivider(),
                SlideTransition(
                  position: _slideAnimations[1],
                  child: _ActivityItem(
                    icon: Icons.message_outlined,
                    title: 'New Message',
                    subtitle: 'From Legal Community Forum',
                    time: '5 hours ago',
                  ),
                ),
                _buildDivider(),
                SlideTransition(
                  position: _slideAnimations[2],
                  child: _ActivityItem(
                    icon: Icons.bookmark_outline,
                    title: 'Document Saved',
                    subtitle: 'Contract Template - Employment Law',
                    time: '1 day ago',
                  ),
                ),
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

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  State<_ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<_ActivityItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered
              ? Colors.grey[850]
              : Colors.transparent,
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



