import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../Services/notification_service.dart';
import '../utils/country_utils.dart';

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

  /// Empty — UI uses [ProfileAvatar.placeholderAsset] for display.
  static const String defaultProfilePic = '';

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

  // --- General error handler for user-friendly messages ---
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support for help.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered. Try logging in instead.';
        case 'weak-password':
          return 'The password is too weak. Please choose a stronger one.';
        case 'account-exists-with-different-credential':
          return 'This account exists with another sign-in method.';
        default:
          return 'Something went wrong. Please try again later.';
      }
    } else if (e is PlatformException) {
      debugPrint('PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'sign_in_failed') {
        return 'Google sign-in failed. Please try again later.';
      }
      return 'An unexpected error occurred. Please try again.';
    } else {
      debugPrint('Unknown error: $e');
      return 'An unknown error occurred. Please try again.';
    }
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
    String countryCode = kDefaultCountryCode,
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
        await _firestore.collection('Users').doc(user.uid).set({
          'Role': false,
          'Fname': firstName,
          'Lname': lastName,
          'Email': email,
          'User ID': user.uid,
          'Mobile Number': phoneNumber,
          'Region': region,
          'Country': countryCode.trim().toUpperCase(),
          'CountryRequired': false,
          'Status': true,
          'User Pic': defaultProfilePic,
          'CreatedAt': Timestamp.now(),
        });

        _currentUser = user;
        // Store FCM token after registration
        final notificationService = NotificationService();
        await notificationService.storeTokenForUserId(user.uid);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = _handleAuthError(e);
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
        DocumentSnapshot userDoc =
        await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists && userDoc['Status'] == true) {
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data != null &&
              (data['Country'] == null ||
                  (data['Country'] is String &&
                      (data['Country'] as String).trim().isEmpty))) {
            await userDoc.reference.set(
              {
                'Country': kDefaultCountryCode,
                'CountryRequired': false,
              },
              SetOptions(merge: true),
            );
          }
          _currentUser = user;
          // Store FCM token after login
          final notificationService = NotificationService();
          await notificationService.storeTokenForUserId(user.uid);
          notifyListeners();
          return true;
        } else {
          await _auth.signOut();
          _errorMessage = 'This account is no longer active.';
        }
      }
    } catch (e) {
      _errorMessage = _handleAuthError(e);
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
      _errorMessage = _handleAuthError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // --- Sign in with Google ---
  /// Returns success and whether the user must pick a country (new Google account or incomplete).
  Future<({bool success, bool needsCountrySelection})> signInWithGoogle(
      BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    var needsCountrySelection = false;
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google sign-in was cancelled.';
        notifyListeners();
        return (success: false, needsCountrySelection: false);
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final DocumentSnapshot userDoc =
            await _firestore.collection('Users').doc(user.uid).get();

        final String displayName = user.displayName ?? '';
        final String firstName = displayName.isNotEmpty
            ? displayName.split(' ').first
            : 'User';
        final String lastName = displayName.contains(' ')
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
            'CountryRequired': true,
            'Status': true,
            'User Pic': user.photoURL ?? defaultProfilePic,
            'CreatedAt': Timestamp.now(),
          });
          needsCountrySelection = true;
        } else if (userDoc['Status'] != true) {
          await _firestore.collection('Users').doc(user.uid).update({
            'Role': false,
            'Fname': firstName,
            'Lname': lastName,
            'Email': user.email ?? googleUser.email,
            'Mobile Number': userDoc['Mobile Number'] ?? '',
            'Region': userDoc['Region'] ?? '',
            'Country': userDoc['Country'] ?? kDefaultCountryCode,
            'CountryRequired': false,
            'Status': true,
            'User Pic':
                user.photoURL ?? userDoc['User Pic'] ?? defaultProfilePic,
            'UpdatedAt': Timestamp.now(),
          });
        } else {
          final data = userDoc.data() as Map<String, dynamic>?;
          final countryMissing = data != null &&
              (data['Country'] == null ||
                  (data['Country'] is String &&
                      (data['Country'] as String).trim().isEmpty));
          if (countryMissing) {
            if (data['CountryRequired'] == true) {
              needsCountrySelection = true;
            } else {
              await _firestore.collection('Users').doc(user.uid).set(
                    {
                      'Country': kDefaultCountryCode,
                      'CountryRequired': false,
                    },
                    SetOptions(merge: true),
                  );
            }
          }
        }

        _currentUser = user;
        final notificationService = NotificationService();
        await notificationService.storeTokenForUserId(user.uid);
        notifyListeners();
        return (success: true, needsCountrySelection: needsCountrySelection);
      }
    } catch (e) {
      _errorMessage = _handleAuthError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return (success: false, needsCountrySelection: false);
  }

  /// Persists chosen ISO country after Google sign-in and clears [CountryRequired].
  Future<bool> completeGoogleCountrySelection(String countryCode) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;
    final code = countryCode.trim().toUpperCase();
    if (code.length != 2) return false;
    try {
      await _firestore.collection('Users').doc(user.uid).set(
        {
          'Country': code,
          'CountryRequired': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('completeGoogleCountrySelection: $e');
      return false;
    }
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
