import 'package:flutter/material.dart';
import 'search_bar.dart';
import 'feature_cards_section.dart';
import 'quick_actions_section.dart';
import 'chambers_section.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Search Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomSearchBar(),
                  const SizedBox(height: 24),
                  _buildWelcomeSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Quick Actions
          const SliverToBoxAdapter(
            child: QuickActionsSection(),
          ),
          
          // Feature Cards
          const SliverToBoxAdapter(
            child: FeatureCardsSection(),
          ),
          
          // Chambers Section
          const SliverToBoxAdapter(
            child: ChambersSection(),
          ),
          
          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to LawHubb',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with legal professionals and access expert advice',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
