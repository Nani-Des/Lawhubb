import 'package:flutter/material.dart';

import '../main_layout.dart';

/// Pushes a full-screen route above [MainLayout] so the shell bottom nav is not duplicated.
Future<T?> pushAppRoute<T>(BuildContext context, Widget page) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(builder: (_) => page),
  );
}

/// Same as [pushAppRoute] for auth-gated navigation (sign-in first if needed).
Future<T?> pushAppRouteAfterAuth<T>(
  BuildContext context,
  Widget Function(String userId) pageBuilder, {
  required Future<String?> Function() signIn,
}) async {
  final userId = await signIn();
  if (userId == null || !context.mounted) return null;
  return pushAppRoute(context, pageBuilder(userId));
}

/// Pops the root route stack; falls back to [MainLayout] when nothing to pop.
void popAppRoute(BuildContext context) {
  final rootNav = Navigator.of(context, rootNavigator: true);
  if (rootNav.canPop()) {
    rootNav.pop();
    return;
  }
  rootNav.pushReplacement(
    MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 0)),
  );
}
