import 'dart:developer';
import 'package:dio/dio.dart';

class YouTubeTrailerSearchService {
  /// Feature flag for experimental client-side YouTube HTML scraping.
  /// Keep disabled (false) by default in production.
  static const bool enableExperimentalClientYoutubeHtmlSearch = false;

  /// Performs trailer resolution with the following priority:
  /// 1. Backend/AI endpoint (if configured).
  /// 2. Client-side public YouTube HTML search scraper (if feature flag is enabled).
  /// 3. Returns null if both are disabled or fail.
  static Future<String?> findTrailerYoutubeId({
    required String cleanTitle,
    String? year,
  }) async {
    if (cleanTitle.trim().isEmpty) return null;

    try {
      // 1. Query Backend / AI Endpoint (Stubbed - return null if no server URL is set)
      final backendTrailerId = await _queryBackendAiEndpoint(cleanTitle, year);
      if (backendTrailerId != null) {
        log("[YOUTUBE_SEARCH] Backend AI successfully resolved trailer for '$cleanTitle': $backendTrailerId");
        return backendTrailerId;
      }

      // 2. Client-side Search Scraper (Isolated behind feature flag)
      if (enableExperimentalClientYoutubeHtmlSearch) {
        log("[YOUTUBE_SEARCH] Triggering experimental client-side search for: '$cleanTitle' (year: $year)");
        final clientTrailerId = await _performClientSearchScrape(cleanTitle, year);
        if (clientTrailerId != null) {
          log("[YOUTUBE_SEARCH] Client scraper successfully resolved trailer for '$cleanTitle': $clientTrailerId");
          return clientTrailerId;
        }
      } else {
        log("[YOUTUBE_SEARCH] Client-side search scraper skipped (flag is disabled).");
      }
    } catch (e) {
      log("[YOUTUBE_SEARCH] Safe error handling: Failed search lookup for '$cleanTitle': $e");
    }

    return null;
  }

  /// Stubbed backend AI search endpoint request
  static Future<String?> _queryBackendAiEndpoint(String cleanTitle, String? year) async {
    // Return null since no production backend is configured for the serverless client
    return null;
  }

  /// Experimental client-side scraper that fetches YouTube search HTML
  /// and parses the videoId from the INITIAL_DATA JSON payload.
  static Future<String?> _performClientSearchScrape(String cleanTitle, String? year) async {
    final dio = Dio();
    
    // Construct safe query
    final queryStr = (year != null && year.trim().isNotEmpty)
        ? "$cleanTitle $year official trailer"
        : "$cleanTitle official trailer";

    final url = "https://www.youtube.com/results?search_query=${Uri.encodeComponent(queryStr)}";

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "en-US,en;q=0.9",
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final html = response.data.toString();
      
      // Match "videoId":"[11 characters]" in the json payload
      final videoIdRegex = RegExp(r'"videoId"\s*:\s*"([a-zA-Z0-9_-]{11})"');
      final matches = videoIdRegex.allMatches(html);

      final List<String> candidateIds = [];
      for (final m in matches) {
        final id = m.group(1);
        if (id != null && _isValidYoutubeId(id)) {
          candidateIds.add(id);
        }
      }

      if (candidateIds.isNotEmpty) {
        // Return the first valid candidate (the top search result on YouTube desktop)
        return candidateIds.first;
      }
    } catch (e) {
      log("[YOUTUBE_SEARCH] Scraping error: $e");
    }

    return null;
  }

  /// Validates the structure of the 11-character YouTube video ID
  static bool _isValidYoutubeId(String id) {
    if (id.length != 11) return false;
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(id);
  }
}
