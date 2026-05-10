/// Shared copy + Play Store link appended for every user-facing share action.
class LawHubbShare {
  LawHubbShare._();

  /// Google Play listing title (display name).
  static const String storeListingName = 'LawHubb';

  /// Android `applicationId` from `android/app/build.gradle`.
  static const String playStoreApplicationId = 'com.lawapp.lawhubb';

  static const String playStoreListingUrl =
      'https://play.google.com/store/apps/details?id=$playStoreApplicationId';

  /// Footer appended after the main shared body (text, links to media, etc.).
  static String buildFooter() {
    return '\n\n—\n$storeListingName — Get the app on Google Play:\n$playStoreListingUrl';
  }

  /// Appends the Play Store footer unless it is already present (avoids duplicates).
  static String withFooter(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return buildFooter().trim();
    }
    if (trimmed.contains(playStoreListingUrl)) {
      return trimmed;
    }
    return '$trimmed${buildFooter()}';
  }
}
