import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Maps errors to safe, user-appropriate copy. Never expose stack traces,
/// Firebase/API details, or configuration messages to end users.
class UserFacingErrors {
  UserFacingErrors._();

  static void log(String context, Object? error, [StackTrace? stackTrace]) {
    debugPrint('[$context] $error${stackTrace != null ? '\n$stackTrace' : ''}');
  }

  /// Firebase Auth / platform sign-in failures.
  static String auth(dynamic error, {String? context}) {
    log(context ?? 'auth', error);
    if (error is FirebaseAuthException) {
      switch (error.code) {
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
        case 'requires-recent-login':
          return 'For your security, please sign in again and try once more.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return network();
        default:
          return generic();
      }
    }
    if (error is PlatformException) {
      if (error.code == 'sign_in_failed') {
        return 'Sign-in failed. Please try again.';
      }
      return generic();
    }
    return generic();
  }

  /// Any unexpected failure; logs [error] in debug builds only.
  static String generic({String? context, Object? error}) {
    if (error != null) log(context ?? 'app', error);
    return 'Something went wrong. Please try again.';
  }

  static String network() =>
      'Please check your internet connection and try again.';

  static String loadFailed({String? item}) =>
      item != null
          ? 'Unable to load $item right now. Please try again.'
          : 'Unable to load this content. Please try again.';

  static String actionFailed({String? action}) =>
      action != null
          ? 'Could not $action. Please try again.'
          : 'That action could not be completed. Please try again.';

  /// For StreamBuilder / FutureBuilder [snapshot.error].
  static String streamLoad({String? context, Object? error}) {
    if (error != null) log(context ?? 'stream', error);
    return 'Unable to load content. Pull down to refresh.';
  }

  static String translation() =>
      'Translation is unavailable right now. Please try again.';

  static String recording() => 'Recording failed. Please try again.';

  static String playback() => 'Playback failed. Please try again.';

  static String upload() => 'Upload failed. Please try again.';

  static String callStart() =>
      'Could not start the call. Please try again later.';

  static String callMic() => 'Could not change microphone. Please try again.';

  static String share() => 'Could not share. Please try again.';

  static String reportSubmit() =>
      'Could not submit your report. Please try again.';

  static String permissions() =>
      'Permission was denied. Enable it in your device settings to continue.';

  static String serviceUnavailable() =>
      'This feature is temporarily unavailable. Please try again later.';

  /// Lawyer registration–specific (StateError codes).
  static String? lawyerRegistrationState(String? message) {
    switch (message) {
      case 'pending':
        return 'You already have a lawyer verification application pending.';
      case 'already_lawyer':
        return 'This account is already verified as a lawyer.';
      default:
        return null;
    }
  }
}
