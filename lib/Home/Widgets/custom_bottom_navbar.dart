import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Home/home_page.dart';
import 'package:nhap/Login/login_screen1.dart';
import 'package:nhap/main.dart';
import '../../Auth/auth_screen.dart';
import '../../Forums/Chat/HomeScreen.dart';
import '../../Hospital/general_hospital_page.dart';
import '../../Library/library_page.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final int setup; // Added parameter to control which setup to use

  const CustomBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.setup,
  }) : super(key: key);

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  late int _selectedIndex;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // 🔹 Navigation logic for each item
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (widget.setup) {
      case 1: // Home
        if (index == 0)
          _navigateBasedOnAuthStatus(context, GeneralHospitalPage());
        else if (index == 1)
          _navigateBasedOnAuthStatus(context, LibraryPage());
        else if (index == 2)
          _navigateBasedOnAuthStatus(
              context, const HomeScreen(initialTabIndex: 0));
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

  // 🔹 Builds items dynamically based on setup
  List<BottomNavigationBarItem> _buildNavItems() {
    switch (widget.setup) {
      case 1:
        return [
          BottomNavigationBarItem(
              icon: Icon(Icons.balance), label: appLocalization!.chambers),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: appLocalization!.lawInsights),
          BottomNavigationBarItem(
              icon: Icon(Icons.forum), label: appLocalization!.socialHubb),
        ];
      case 2:
        return [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: appLocalization!.home),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: appLocalization!.lawInsights),
          BottomNavigationBarItem(
              icon: Icon(Icons.forum), label: appLocalization!.socialHubb),
        ];
      case 3:
        return [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: appLocalization!.home),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: appLocalization!.lawInsights),
          BottomNavigationBarItem(
              icon: Icon(Icons.balance), label: appLocalization!.chambers),
        ];
      case 4:
        return [
          BottomNavigationBarItem(
              icon: Icon(Icons.search), label: appLocalization!.search),
          BottomNavigationBarItem(
              icon: Icon(Icons.create), label: appLocalization!.createPost),
          BottomNavigationBarItem(
              icon: Icon(Icons.videocam), label: appLocalization!.live),
        ];
      case 5:
        return [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: appLocalization!.home),
          BottomNavigationBarItem(
              icon: Icon(Icons.balance), label: appLocalization!.chambers),
          BottomNavigationBarItem(
              icon: Icon(Icons.forum), label: appLocalization!.socialHubb),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            items: _buildNavItems(),
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle:
                const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 8.0),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
