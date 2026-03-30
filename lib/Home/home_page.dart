import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../Auth/auth_screen.dart';
import '../Forums/Public/Widgets/user_profile_screen.dart';
import '../bot/chat_bot.dart';
import 'Widgets/profile_drawer.dart';
import 'Widgets/redesigned_home_content.dart';
import 'Widgets/app_bar.dart';

class HomePage extends StatefulWidget {
  final Function(int)? onTabChange;

  const HomePage({
    super.key,
    this.onTabChange,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  User? currentUser;
  String? userImageUrl;
  String? userFirstName;
  bool showProfileDrawer = false;
  AnimationController? _drawerController;
  Animation<Offset>? _slideAnimation;
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupCallService();
    _fetchUserData();
    _setupShowcase();
  }

  void _initializeAnimations() {
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Animation now goes from bottom to top (fully visible)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from bottom (off-screen)
      end: const Offset(0, 0), // End at top (fully visible)
    ).animate(CurvedAnimation(
      parent: _drawerController!,
      curve: Curves.easeInOut,
    ));
  }

  void _setupCallService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CallService().setContext(context);
    });
  }

  void _setupShowcase() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenWalkthrough =
          prefs.getBool('hasSeenEmergencyWalkthrough') ?? false;
      if (!hasSeenWalkthrough && mounted) {
        ShowCaseWidget.of(context).startShowCase([_fabKey]);
        await prefs.setBool('hasSeenEmergencyWalkthrough', true);
      }
    });
  }

  Future<void> _fetchUserData() async {
    final logFile = File(
        r'c:\Users\HP\PROJECTS\flutter_projects\lawhubb\Lawhubb\.cursor\debug.log');
    void debugLog(
        String hypothesisId, String message, Map<String, dynamic> data) {
      try {
        final entry =
            '{"hypothesisId":"$hypothesisId","location":"home_page.dart:_fetchUserData","message":"$message","data":${data.toString().replaceAll("'", '"')},"timestamp":${DateTime.now().millisecondsSinceEpoch},"sessionId":"debug-session"}\n';
        logFile.writeAsStringSync(entry, mode: FileMode.append);
      } catch (_) {}
    }

    User? user = FirebaseAuth.instance.currentUser;
    debugLog('A', 'Auth state check', {
      'userIsNull': user == null,
      'userId': user?.uid ?? 'null',
      'isEmailVerified': user?.emailVerified ?? false
    });

    if (user != null) {
      debugLog('B', 'Before Firestore query',
          {'userId': user.uid, 'collection': 'Users'});
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
        debugLog('C', 'Firestore query success',
            {'docExists': docSnapshot.exists, 'userId': user.uid});

        if (mounted) {
          setState(() {
            currentUser = user;
            userImageUrl = docSnapshot.data()?['User Pic'] ?? '';
            userFirstName = docSnapshot.data()?['Fname'] as String?;
          });
        }
      } catch (e) {
        debugLog('A', 'Firestore query FAILED',
            {'error': e.toString(), 'userId': user.uid});
        print('Unknown error: $e');
      }
    } else {
      debugLog('B', 'No authenticated user', {'userIsNull': true});
      if (mounted) {
        setState(() {
          currentUser = null;
          userImageUrl = null;
          userFirstName = null;
        });
      }
    }
  }

  void _onAvatarTap() async {
    if (currentUser == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
      if (result == true || result == null) {
        _fetchUserData();
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(userId: currentUser!.uid),
        ),
      );
    }
  }

  void _toggleProfileDrawer() async {
    if (!showProfileDrawer) {
      await _fetchUserData();
    }

    if (_drawerController != null) {
      setState(() {
        showProfileDrawer = !showProfileDrawer;
        showProfileDrawer
            ? _drawerController!.forward()
            : _drawerController!.reverse();
      });
    }
  }

  @override
  void dispose() {
    _drawerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        userImageUrl: userImageUrl,
        onAvatarTap: _onAvatarTap,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        tooltip: 'Legal Aid Assistant',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatBotScreen()),
        ),
        child: const Icon(Icons.smart_toy),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUserData,
        color: Colors.white,
        backgroundColor: Colors.grey[900],
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              child: RedesignedHomeContent(
                onTabChange: widget.onTabChange,
                currentUser: currentUser,
                userName: userFirstName,
              ),
            ),
            if (_drawerController != null && _slideAnimation != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: ProfileDrawer(
                  controller: _drawerController!,
                  slideAnimation: _slideAnimation!,
                  showProfileDrawer: showProfileDrawer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
