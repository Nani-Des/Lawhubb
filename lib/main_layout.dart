import 'package:flutter/material.dart';
import 'Home/home_page.dart';
import 'Library/library_page.dart';
import 'wrappers/chambers_content.dart';
import 'wrappers/social_content.dart';
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
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPageForSetup(int setup, int index) {
    switch (setup) {
      case 1: // Home setup (default)
        switch (index) {
          case 0:
            return const HomePage(); // Home
          case 1:
            return ChambersContent(); // Chambers
          case 2:
            return LibraryPage(); // Law Insights
          case 3:
            return const SocialContent(initialTabIndex: 0); // SocialHubb
          default:
            return const HomePage();
        }
      case 2: // Chambers setup
        switch (index) {
          case 0:
            return const HomePage(); // Home
          case 1:
            return LibraryPage(); // Law Insights
          case 2:
            return const SocialContent(initialTabIndex: 1); // SocialHubb
          default:
            return const HomePage();
        }
      case 3: // Social setup
        switch (index) {
          case 0:
            return const HomePage(); // Home
          case 1:
            return LibraryPage(); // Law Insights
          case 2:
            return ChambersContent(); // Chambers
          default:
            return const HomePage();
        }
      case 5: // Law insights setup
        switch (index) {
          case 0:
            return const HomePage(); // Home
          case 1:
            return ChambersContent(); // Chambers
          case 2:
            return const SocialContent(initialTabIndex: 1); // SocialHubb
          default:
            return const HomePage();
        }
      default:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
