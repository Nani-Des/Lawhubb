import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Home/home_page.dart';
import 'package:nhap/Login/login_screen1.dart';
import '../../Auth/auth_screen.dart';
import '../../ChatModule/chat_module.dart';
import '../../Forums/Chat/HomeScreen.dart';
import '../../Forums/Public/forum.dart';
import '../../Hospital/general_hospital_page.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int selectedIndex;

  // Constructor to accept selectedIndex
  CustomBottomNavBar({Key? key, required this.selectedIndex}) : super(key: key);

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  late int _selectedIndex;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex; // Initialize with passed index
  }

  // Check if user is signed in
  Future<void> _navigateBasedOnAuthStatus(BuildContext context, Widget Function(String) targetScreen) async {
    User? currentUser = _auth.currentUser;
    String? userId;

    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      userId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
    }

    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen(userId!)),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        _navigateBasedOnAuthStatus(context, (userId) => GeneralHospitalPage());
        break;
      case 1:
        _navigateBasedOnAuthStatus(context, (userId) => HomePage());
        break;
      case 2:
        _navigateBasedOnAuthStatus(context, (userId) => HomeScreen());
        // _navigateBasedOnAuthStatus(context, (userId) => Forum(userId: 'FyhGd0I6FMb3pKYfHMHxL9gemIq2',));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],  // Dark grey background
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,  // Darker shadow for contrast
                blurRadius: 10,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Chambers',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.forum_rounded),
                label: 'Blog',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.white,  // White for selected items
            unselectedItemColor: Colors.grey[400],  // Light grey for unselected
            selectedLabelStyle:
            TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 8.0),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}