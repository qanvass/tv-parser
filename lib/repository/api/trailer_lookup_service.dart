import 'dart:developer';

class TrailerLookupService {
  /// Resolves the YouTube video ID from provider metadata or fallback strategies.
  static String? getYoutubeIdFromMetadata(dynamic detail) {
    if (detail == null) return null;
    
    String? rawTrailer;
    
    if (detail is Map) {
      rawTrailer = _findValueInMap(detail, [
        'youtube_trailer', 
        'youtubeTrailer', 
        'trailer', 
        'youtube', 
        'youtube_id', 
        'youtubeId',
        'video'
      ]);
    } else {
      // It's a typed object like MovieDetail or SerieDetails
      try {
        rawTrailer = detail.youtubeTrailer?.toString() ??
                     detail.info?.youtubeTrailer?.toString() ??
                     detail.movieData?.youtubeTrailer?.toString();
      } catch (_) {
        try {
          if (detail.info != null) {
            rawTrailer = detail.info.youtubeTrailer;
          }
        } catch (_) {}
      }
    }
    
    if (rawTrailer != null && rawTrailer.isNotEmpty && rawTrailer != "null") {
      final id = extractYoutubeId(rawTrailer);
      if (id != null) {
        log("TrailerLookupService: Resolved YouTube ID from metadata field: $id");
        return id;
      }
    }
    
    return null;
  }

  /// Extracts the 11-character YouTube video ID from a URL or raw string.
  static String? extractYoutubeId(String? input) {
    if (input == null || input.isEmpty) return null;
    
    final trimmed = input.trim();
    final idPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    
    // 1. Check if it is already a clean 11-character ID
    if (idPattern.hasMatch(trimmed)) {
      return trimmed;
    }
    
    // 2. Standard YouTube URL regex pattern matching (handles watch?v=, embed/, youtu.be/)
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      if (id != null && idPattern.hasMatch(id)) {
        return id;
      }
    }
    
    // 3. Fallback manually parse v= parameter if regex missed
    if (trimmed.contains('v=')) {
      final parts = trimmed.split('v=');
      if (parts.length > 1) {
        final candidate = parts[1].split('&').first.split('?').first;
        if (idPattern.hasMatch(candidate)) return candidate;
      }
    }

    // 4. Fallback manually parse embed path
    if (trimmed.contains('/embed/')) {
      final parts = trimmed.split('/embed/');
      if (parts.length > 1) {
        final candidate = parts[1].split('&').first.split('?').first;
        if (idPattern.hasMatch(candidate)) return candidate;
      }
    }
    
    return null;
  }

  /// Helper to safely search nested maps for potential keys
  static String? _findValueInMap(Map map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key].toString();
      }
    }
    // Search nested inside 'info' or 'movie_data'
    if (map.containsKey('info') && map['info'] is Map) {
      final val = _findValueInMap(map['info'] as Map, keys);
      if (val != null) return val;
    }
    if (map.containsKey('movie_data') && map['movie_data'] is Map) {
      final val = _findValueInMap(map['movie_data'] as Map, keys);
      if (val != null) return val;
    }
    return null;
  }

  /// If no trailer is found, generates a safe fallback search/watch link or query.
  static String getSearchFallbackUrl(String title) {
    final query = Uri.encodeComponent("$title official trailer");
    return "https://www.youtube.com/results?search_query=$query";
  }
}
