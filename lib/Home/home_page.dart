import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../Auth/auth_screen.dart';
import 'Widgets/profile_drawer.dart';
import 'Widgets/redesigned_home_content.dart';
import 'Widgets/app_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  User? currentUser;
  String? userImageUrl;
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0.3),
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
        });
      }
    }
  }

  void _onAvatarTap() async {
    if (currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
      _fetchUserData();
    } else {
      _toggleProfileDrawer();
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
      body: RefreshIndicator(
        onRefresh: _fetchUserData,
        color: Colors.white,
        backgroundColor: Colors.grey[900],
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              child: const RedesignedHomeContent(),
            ),
            if (_drawerController != null && _slideAnimation != null)
              ProfileDrawer(
                controller: _drawerController!,
                slideAnimation: _slideAnimation!,
                showProfileDrawer: showProfileDrawer,
              ),
          ],
        ),
      ),
    );
  }
}
