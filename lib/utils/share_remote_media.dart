import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'lawhubb_share.dart';

/// Downloads remote media and shares the file so recipients get the asset, not only a URL.
Future<bool> shareRemoteVideoWithCaption({
  required String videoUrl,
  required String caption,
}) async {
  final uri = Uri.tryParse(videoUrl.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return false;
  }
  try {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/lawhubb_share_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final resp = await http.get(uri).timeout(const Duration(minutes: 3));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return false;
    await File(path).writeAsBytes(resp.bodyBytes);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'video/mp4')],
      text: LawHubbShare.withFooter(caption.trim()),
      subject: LawHubbShare.storeListingName,
    );
    return true;
  } catch (e, st) {
    debugPrint('shareRemoteVideoWithCaption: $e\n$st');
    return false;
  }
}

Future<bool> shareRemoteImageWithCaption({
  required String imageUrl,
  required String caption,
}) async {
  final uri = Uri.tryParse(imageUrl.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return false;
  }
  try {
    final dir = await getTemporaryDirectory();
    final lower = imageUrl.toLowerCase();
    final ext =
        lower.endsWith('.png') ? 'png' : (lower.endsWith('.webp') ? 'webp' : 'jpg');
    final mime = ext == 'png'
        ? 'image/png'
        : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final path =
        '${dir.path}/lawhubb_share_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final resp = await http.get(uri).timeout(const Duration(minutes: 2));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return false;
    await File(path).writeAsBytes(resp.bodyBytes);
    await Share.shareXFiles(
      [XFile(path, mimeType: mime)],
      text: LawHubbShare.withFooter(caption.trim()),
      subject: LawHubbShare.storeListingName,
    );
    return true;
  } catch (e, st) {
    debugPrint('shareRemoteImageWithCaption: $e\n$st');
    return false;
  }
}
