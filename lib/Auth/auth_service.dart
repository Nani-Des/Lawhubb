import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../Services/notification_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const String defaultProfilePic =
      'https://firebasestorage.googleapis.com/v0/b/mhealth-6191e.appspot.com/o/assets%2Fplaceholder.png?alt=media&token=3350f551-d18e-44ed-939a-095b8a66a2a7';

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  // Validate email format
  static bool isValidEmail(String email) {
    final emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // --- Internal logger — never surfaces raw errors to users ---
  void _logAuthEvent(String operation, dynamic e) {
    if (e is FirebaseAuthException) {
      debugPrint('[Auth][$operation] code=${e.code}');
    } else if (e is PlatformException) {
      debugPrint('[Auth][$operation] platform_code=${e.code}');
    } else {
      debugPrint('[Auth][$operation] type=${e.runtimeType}');
    }
  }

  // --- Generic user-facing messages — no information that aids enumeration ---
  String _handleAuthError(dynamic e, {String operation = 'unknown'}) {
    _logAuthEvent(operation, e);
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Please choose a stronger password (at least 8 characters).';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
            case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes before trying again.';
        // All account-state and credential errors get the same generic message
        // to prevent user enumeration and credential confirmation attacks.
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-disabled':
        case 'email-already-in-use':
        case 'account-exists-with-different-credential':
        default:
          return 'Something went wrong. Please check your details and try again.';
      }
    } else if (e is PlatformException) {
      return 'Sign-in could not be completed. Please try again.';
    }
    return 'Something went wrong. Please try again later.';
  }

  // --- Register user with email and password ---
  Future<bool> registerUser({
    required BuildContext context,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    String region = '',
  }) async {
    if (!isValidEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        try {
          await _firestore.collection('Users').doc(user.uid).set({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': email,
            'User ID': user.uid,
            'Mobile Number': phoneNumber,
            'Region': region,
            'Status': true,
            'User Pic': defaultProfilePic,
            'CreatedAt': Timestamp.now(),
          });
        } catch (firestoreError) {
          // Firestore write failed — delete the Auth account so the user
          // can retry registration rather than getting email-already-in-use.
          await user.delete();
          rethrow;
        }

        _currentUser = user;
        _isLoading = false;
        // Store FCM token after registration
        final notificationService = NotificationService();
        await notificationService.storeTokenForUserId(user.uid);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = _handleAuthError(e, operation: 'register');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // --- Sign in with email and password ---
  Future<bool> signInUser({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    if (!isValidEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;
      if (user != null) {
        try {
          final userDoc = await _firestore
              .collection('Users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 8));
          if (userDoc.exists && userDoc['Status'] == true) {
            _currentUser = user;
            _isLoading = false;
            final notificationService = NotificationService();
            await notificationService.storeTokenForUserId(user.uid);
            notifyListeners();
            return true;
          } else if (userDoc.exists && userDoc['Status'] != true) {
            await _auth.signOut();
            _errorMessage = 'This account is no longer active.';
          } else {
            // Doc doesn't exist yet (race condition) — still allow login
            _currentUser = user;
            _isLoading = false;
            notifyListeners();
            return true;
          }
        } catch (_) {
          // Firestore unreachable — trust Firebase Auth and proceed
          _currentUser = user;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _errorMessage = _handleAuthError(e, operation: 'sign_in');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // --- Reset password ---
  Future<bool> resetPassword({
    required BuildContext context,
    required String email,
  }) async {
    if (!isValidEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _errorMessage = _handleAuthError(e, operation: 'reset_password');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // --- Sign in with Google ---
  Future<bool> signInWithGoogle(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google sign-in was cancelled.';
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc =
        await _firestore.collection('Users').doc(user.uid).get();

        String displayName = user.displayName ?? '';
        String firstName =
        displayName.isNotEmpty ? displayName.split(' ').first : 'User';
        String lastName = displayName.contains(' ')
            ? displayName.split(' ').sublist(1).join(' ')
            : '';

        if (!userDoc.exists) {
          await _firestore.collection('Users').doc(user.uid).set({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': user.email ?? googleUser.email,
            'User ID': user.uid,
            'Mobile Number': '',
            'Region': '',
            'Status': true,
            'User Pic': user.photoURL ?? defaultProfilePic,
            'CreatedAt': Timestamp.now(),
          });
        } else if (userDoc['Status'] != true) {
          await _firestore.collection('Users').doc(user.uid).update({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': user.email ?? googleUser.email,
            'Mobile Number': userDoc['Mobile Number'] ?? '',
            'Region': userDoc['Region'] ?? '',
            'Status': true,
            'User Pic': user.photoURL ?? userDoc['User Pic'] ?? defaultProfilePic,
            'UpdatedAt': Timestamp.now(),
          });
        }

        _currentUser = user;
        // Store FCM token after Google sign in
        final notificationService = NotificationService();
        await notificationService.storeTokenForUserId(user.uid);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = _handleAuthError(e, operation: 'google_sign_in');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // --- Sign out ---
  Future<void> signOut() async {
    // Clear FCM token on logout
    final notificationService = NotificationService();
    await notificationService.clearToken();
    await _googleSignIn.signOut();
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
