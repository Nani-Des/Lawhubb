import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Home/home_page.dart';
import 'package:nhap/main.dart';
import '../../Auth/auth_screen.dart';
import '../../Forums/Chat/HomeScreen.dart';
import '../../Hospital/general_hospital_page.dart';
import '../../Library/library_page.dart';
import '../../ChatModule/chat_module.dart';
import '../../wrappers/chambers_content.dart';
import '../../wrappers/social_content.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final int setup; // Added parameter to control which setup to use
  final Function(int)?
      onItemTapped; // Optional callback for parent to handle navigation

  const CustomBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.setup,
    this.onItemTapped,
  }) : super(key: key);

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  late int _selectedIndex;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void didUpdateWidget(covariant CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _selectedIndex = widget.selectedIndex;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  // 🔹 Authentication check before navigation
  Future<void> _navigateBasedOnAuthStatus(
      BuildContext context, Widget targetScreen) async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    } else {
      final userId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );

      if (userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      }
    }
  }

  // 🔹 Action handlers for setup 4
  void _onSearchPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search feature coming soon!')),
    );
  }

  void _onCreatePostPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create Post feature coming soon!')),
    );
  }

  void _onLivePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live feature coming soon!')),
    );
  }

  // 🔹 Builds items dynamically based on setup
  List<_NavItem> _buildNavItems() {
    switch (widget.setup) {
      case 1:
        return const [
          _NavItem(icon: Icons.home_filled, label: 'Home'),
          _NavItem(icon: Icons.balance, label: 'Chambers'),
          _NavItem(icon: Icons.chat_bubble_outline, label: 'Chats'),
          _NavItem(icon: Icons.forum, label: 'SocialHubb'),
        ];
      case 2:
        return const [
          _NavItem(icon: Icons.home_filled, label: 'Home'),
          _NavItem(icon: Icons.menu_book, label: 'Law Insights'),
          _NavItem(icon: Icons.forum, label: 'SocialHubb'),
        ];
      case 3:
        return const [
          _NavItem(icon: Icons.home_filled, label: 'Home'),
          _NavItem(icon: Icons.menu_book, label: 'Law Insights'),
          _NavItem(icon: Icons.balance, label: 'Chambers'),
        ];
      case 4:
        return const [
          _NavItem(icon: Icons.search, label: 'Search'),
          _NavItem(icon: Icons.create, label: 'Create Post'),
          _NavItem(icon: Icons.videocam, label: 'Live'),
        ];
      case 5:
        return const [
          _NavItem(icon: Icons.home_filled, label: 'Home'),
          _NavItem(icon: Icons.balance, label: 'Chambers'),
          _NavItem(icon: Icons.forum, label: 'SocialHubb'),
        ];
      default:
        return const [];
    }
  }

  // 🔹 Navigation logic for each item
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    // Use callback if provided (for MainLayout), otherwise use old navigation
    if (widget.onItemTapped != null) {
      widget.onItemTapped!(index);
      return;
    }

    // Fallback to old navigation for backward compatibility
    switch (widget.setup) {
      case 1: // Home setup (default)
        if (index == 0) _navigateBasedOnAuthStatus(context, const HomePage());
        else if (index == 1) _navigateBasedOnAuthStatus(context, ChambersContent());
        else if (index == 2) _navigateBasedOnAuthStatus(context, const ChatHomePage());
        else if (index == 3) _navigateBasedOnAuthStatus(context, const SocialContent(initialTabIndex: 0));
        break;

      case 2: // Chambers
        if (index == 0)
          _navigateBasedOnAuthStatus(context, HomePage());
        else if (index == 1)
          _navigateBasedOnAuthStatus(context, LibraryPage());
        else if (index == 2)
          _navigateBasedOnAuthStatus(
              context, const HomeScreen(initialTabIndex: 1));
        break;

      case 3: // Social
        if (index == 0)
          _navigateBasedOnAuthStatus(context, HomePage());
        else if (index == 1)
          _navigateBasedOnAuthStatus(context, LibraryPage());
        else if (index == 2)
          _navigateBasedOnAuthStatus(context, GeneralHospitalPage());
        break;

      case 4: // Forum
        if (index == 0)
          _onSearchPressed();
        else if (index == 1)
          _onCreatePostPressed();
        else if (index == 2) _onLivePressed();
        break;

      case 5: // Law insights
        if (index == 0)
          _navigateBasedOnAuthStatus(context, HomePage());
        else if (index == 1)
          _navigateBasedOnAuthStatus(context, GeneralHospitalPage());
        else if (index == 2)
          _navigateBasedOnAuthStatus(
              context, const HomeScreen(initialTabIndex: 1));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _buildNavItems();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = index == _selectedIndex;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _onItemTapped(index),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color:
                                    isSelected ? Colors.white : Colors.white70,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}
