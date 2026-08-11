import 'package:flutter/foundation.dart';

/// TVmaze client stub (no API key required for public endpoints).
/// Feature-flagged; does not invent titles or artwork.
class TvmazeClient {
  static const bool enableTvmaze = bool.fromEnvironment(
    'ENABLE_TVMAZE',
    defaultValue: false,
  );

  bool get isEnabled => enableTvmaze;

  /// No-op until enabled + HTTP wired. Never invents metadata.
  Future<Map<String, dynamic>?> searchShow(String title) async {
    if (!isEnabled) return null;
    debugPrint(
      '[TVMAZE] searchShow stub (enabled but HTTP not wired): title_len=${title.length}',
    );
    return null;
  }
}
