import '../../../repository/api/trailer_lookup_service.dart';

/// Direct video URLs only. Reuses [TrailerLookupService] to reject YouTube ids.
/// Never invents a search URL or a second metadata pipeline.
class PlayableTrailerUrl {
  static final _videoExt = RegExp(
    r'\.(mp4|m3u8|webm|mov|mkv)(\?|#|$)',
    caseSensitive: false,
  );

  static String? resolve(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    // Existing YouTube-id helper — a YouTube id is not a VLC/file URL.
    if (TrailerLookupService.extractYoutubeId(s) != null) return null;
    if (!(s.startsWith('http://') || s.startsWith('https://'))) return null;
    if (!_videoExt.hasMatch(s)) return null;
    return s;
  }
}
