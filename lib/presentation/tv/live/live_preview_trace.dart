import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Temporary diagnostic tracer. Never logs a full stream URL.
abstract final class LivePreviewTrace {
  static String urlHash(String? url) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return 'none';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 8);
  }

  static void log(String stage, [String detail = '']) {
    // Release diagnostic bake: use print (debugPrint can throttle/drop on TV).
    // Still never logs URLs.
    final extra = detail.isEmpty ? '' : ' $detail';
    // ignore: avoid_print
    print('[LIVE_PREVIEW_TRACE] $stage$extra');
  }
}
