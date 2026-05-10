import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Requests OS location permission when appropriate (no extra onboarding UI).
Future<void> requestAppLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('Location permissions denied');
      return;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    debugPrint('Location permissions permanently denied');
    return;
  }
  debugPrint('Location permissions granted');
}
