enum CastCompatibilityStatus {
  supportedLikely,
  risky,
  unsupportedLikely,
}

class CastCompatibilityResult {
  final CastCompatibilityStatus status;
  final String contentType;
  final bool requiresHeaders;
  final String userMessage;

  CastCompatibilityResult({
    required this.status,
    required this.contentType,
    required this.requiresHeaders,
    required this.userMessage,
  });
}

class CastCompatibilityService {
  /// Analyzes a stream URL and determines its compatibility profile.
  static CastCompatibilityResult checkCompatibility(String? url) {
    if (url == null || url.isEmpty) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.unsupportedLikely,
        contentType: 'video/mp4',
        requiresHeaders: false,
        userMessage: "Casting is unavailable for this stream type.",
      );
    }

    final lowerUrl = url.toLowerCase();
    
    // Check if custom headers/user-agents/cookies/referer are embedded or required in the stream params.
    final hasHeaders = lowerUrl.contains('user-agent=') || 
                       lowerUrl.contains('http-user-agent=') || 
                       lowerUrl.contains('referer=') || 
                       lowerUrl.contains('cookie=') || 
                       lowerUrl.contains('headers=');

    if (hasHeaders) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.unsupportedLikely,
        contentType: 'video/mp4',
        requiresHeaders: true,
        userMessage: "This channel requires playback headers that Chromecast may not support. Play locally or try another channel.",
      );
    }

    // Remove query parameters to extract file extension
    final cleanUrl = lowerUrl.split('?').first;

    if (cleanUrl.endsWith('.m3u8')) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.supportedLikely,
        contentType: 'application/x-mpegURL',
        requiresHeaders: false,
        userMessage: "HLS Stream is likely supported by Chromecast.",
      );
    } else if (cleanUrl.endsWith('.mp4')) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.supportedLikely,
        contentType: 'video/mp4',
        requiresHeaders: false,
        userMessage: "MP4 Video is likely supported by Chromecast.",
      );
    } else if (cleanUrl.endsWith('.mpd')) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.supportedLikely,
        contentType: 'application/dash+xml',
        requiresHeaders: false,
        userMessage: "DASH Stream is likely supported by Chromecast.",
      );
    } else if (cleanUrl.endsWith('.ts')) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.risky,
        contentType: 'video/mp2t',
        requiresHeaders: false,
        userMessage: "This stream may not be fully compatible with Chromecast video playback. If video does not appear, play locally or try another channel.",
      );
    } else if (cleanUrl.endsWith('.mkv')) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.unsupportedLikely,
        contentType: 'video/x-matroska',
        requiresHeaders: false,
        userMessage: "MKV container is unsupported likely on Chromecast. Play locally.",
      );
    } else if (cleanUrl.endsWith('.avi')) {
      return CastCompatibilityResult(
        status: CastCompatibilityStatus.unsupportedLikely,
        contentType: 'video/x-msvideo',
        requiresHeaders: false,
        userMessage: "AVI container is unsupported likely on Chromecast. Play locally.",
      );
    }

    // Default fallback
    return CastCompatibilityResult(
      status: CastCompatibilityStatus.risky,
      contentType: 'video/mp4',
      requiresHeaders: false,
      userMessage: "Unknown stream format. Casting compatibility is risky.",
    );
  }
}
