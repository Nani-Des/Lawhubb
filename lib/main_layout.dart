import 'package:flutter/material.dart';
import 'package:nhap/utils/location_permission.dart';
import 'Home/home_page.dart';
import 'LawInsights/law_insights_page.dart';
import 'wrappers/posts_content.dart';
import 'wrappers/chats_content.dart';
import 'Home/Widgets/custom_bottom_navbar.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  final int setup;

  const MainLayout({
    super.key,
    this.initialIndex = 0,
    this.setup = 1,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;
  late int _currentSetup;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _currentSetup = widget.setup;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestAppLocationPermission();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPageForSetup(int setup, int index) {
    switch (setup) {
      case 1:
        switch (index) {
          case 0:
            return HomePage(onTabChange: _onItemTapped);
          case 1:
            return const LawInsightsPage();
          case 2:
            return const ChatsContent();
          case 3:
            return const PostsContent();
          default:
            return HomePage(onTabChange: _onItemTapped);
        }
      case 2:
        switch (index) {
          case 0:
            return HomePage(onTabChange: _onItemTapped);
          case 1:
            return const ChatsContent();
          case 2:
            return const PostsContent();
          default:
            return HomePage(onTabChange: _onItemTapped);
        }
      case 3:
        switch (index) {
          case 0:
            return HomePage(onTabChange: _onItemTapped);
          case 1:
            return const ChatsContent();
          case 2:
            return const LawInsightsPage();
          default:
            return HomePage(onTabChange: _onItemTapped);
        }
      case 5:
        switch (index) {
          case 0:
            return HomePage(onTabChange: _onItemTapped);
          case 1:
            return const LawInsightsPage();
          case 2:
            return const PostsContent();
          default:
            return HomePage(onTabChange: _onItemTapped);
        }
      default:
        return HomePage(onTabChange: _onItemTapped);
    }
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _getPageForSetup(_currentSetup, _selectedIndex),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: _selectedIndex,
          setup: _currentSetup,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}
