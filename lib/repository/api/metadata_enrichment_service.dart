import 'trailer_lookup_service.dart';
import 'gemini_channel_intelligence_service.dart';

class MetadataEnrichmentService {
  /// Advertisements and placeholder keywords typically returned by low-quality IPTV lists
  static const List<String> _iptvSpamKeywords = [
    'watch iptv',
    'premium subscription',
    'reseller panel',
    'iptv server',
    'apollo group',
    'best server',
    'download list',
    'unlimited channels',
    'xtream codes',
    'buy subscription',
  ];

  /// Cleans and sanitizes plot synopsis, removing IPTV advertisements and providing fallbacks
  static String cleanPlot(String? input) {
    if (input == null || input.trim().isEmpty || input.trim().toLowerCase() == "null") {
      return "No description available for this title.";
    }

    final clean = input.trim();
    final lower = clean.toLowerCase();

    // Check for spam advertisement keywords
    for (final kw in _iptvSpamKeywords) {
      if (lower.contains(kw)) {
        return "No description available for this title.";
      }
    }

    // Check if the description is ridiculously short or looks like a file name
    if (clean.length < 5 || clean.startsWith('/') || clean.contains('.mp4') || clean.contains('.mkv')) {
      return "No description available for this title.";
    }

    return clean;
  }

  /// Resolves trailer URL or video ID from provider metadata
  static String? getTrailerYoutubeId(dynamic detail) {
    return TrailerLookupService.getYoutubeIdFromMetadata(detail);
  }

  /// Generates clean search fallback link for trailers
  static String getTrailerSearchFallback(String title) {
    return TrailerLookupService.getSearchFallbackUrl(title);
  }

  /// Attempts Gemini enrichment for description/genres when plot is missing or spam.
  static Future<Map<String, dynamic>?> enrichTitleAsync({
    required String title,
    String? year,
    String contentType = 'movie',
    String? existingPlot,
  }) async {
    final cleaned = cleanPlot(existingPlot);
    final needsEnrichment = cleaned == "No description available for this title.";
    if (!needsEnrichment && existingPlot != null && existingPlot.trim().isNotEmpty) {
      return {'description': cleaned, 'genres': <String>[]};
    }
    return GeminiChannelIntelligenceService.enrichTitle(
      title: title,
      year: year,
      contentType: contentType,
      existingPlot: existingPlot,
    );
  }
}
