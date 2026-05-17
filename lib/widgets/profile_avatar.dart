import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Default avatar when no profile image URL is set.
class ProfileAvatar {
  ProfileAvatar._();

  static const String placeholderAsset = 'assets/Images/placeholder.png';

  static bool hasNetworkImage(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == placeholderAsset) return false;
    if (trimmed.contains('placeholder.png')) return false;
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  static ImageProvider provider(String? url, {File? localFile}) {
    if (localFile != null) return FileImage(localFile);
    if (hasNetworkImage(url)) return NetworkImage(url!.trim());
    return const AssetImage(placeholderAsset);
  }

  static Widget assetPlaceholder({double? size, BoxFit fit = BoxFit.cover}) {
    return Image.asset(
      placeholderAsset,
      width: size,
      height: size,
      fit: fit,
    );
  }

  /// Circular avatar — network URL, local file, or [placeholderAsset].
  static Widget circle({
    String? imageUrl,
    File? imageFile,
    double radius = 20,
    Color? backgroundColor,
    Widget? child,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[800],
      backgroundImage: provider(imageUrl, localFile: imageFile),
      child: child,
    );
  }

  /// Rounded / circular network image with asset fallback while loading or on error.
  static Widget clippedNetwork({
    required String? imageUrl,
    required double size,
    BoxFit fit = BoxFit.cover,
    bool circular = true,
  }) {
    final fallback = assetPlaceholder(size: size, fit: fit);
    if (!hasNetworkImage(imageUrl)) {
      return circular
          ? ClipOval(child: fallback)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: fallback,
            );
    }
    final image = CachedNetworkImage(
      imageUrl: imageUrl!.trim(),
      width: size,
      height: size,
      fit: fit,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
    return circular
        ? ClipOval(child: image)
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          );
  }
}
