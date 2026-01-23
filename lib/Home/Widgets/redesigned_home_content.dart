import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hero_section.dart';
import 'stats_section.dart';
import 'services_grid.dart';
import 'recent_activity.dart';
import 'trending_topics.dart';

class RedesignedHomeContent extends StatefulWidget {
  final Function(int)? onTabChange;
  final User? currentUser;

  const RedesignedHomeContent({
    super.key,
    this.onTabChange,
    this.currentUser,
  });

  @override
  State<RedesignedHomeContent> createState() => _RedesignedHomeContentState();
}

class _RedesignedHomeContentState extends State<RedesignedHomeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _userName {
    if (widget.currentUser?.displayName != null) {
      return widget.currentUser!.displayName!.split(' ').first;
    }
    return 'Guest';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: HeroSection(
              userName: _userName,
              isLoggedIn: widget.currentUser != null,
            ),
          ),
          
          const SliverToBoxAdapter(
            child: StatsSection(),
          ),
          
          SliverToBoxAdapter(
            child: ServicesGrid(
              onTabChange: widget.onTabChange,
            ),
          ),
          
          if (widget.currentUser != null)
             SliverToBoxAdapter(
              child: RecentActivity(
                onTabChange: widget.onTabChange,
              ),
            ),
          
          const SliverToBoxAdapter(
            child: TrendingTopics(),
          ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}



