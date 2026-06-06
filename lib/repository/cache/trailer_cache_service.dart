import 'dart:developer';
import 'package:get_storage/get_storage.dart';

class TrailerCacheEntry {
  final String normalizedTitle;
  final String? year;
  final String? youtubeId;
  final String source; // 'xtream', 'backend', 'youtubeApi', 'manual', 'none'
  final bool failedLookup;
  final int createdAtMillis;

  TrailerCacheEntry({
    required this.normalizedTitle,
    this.year,
    this.youtubeId,
    required this.source,
    required this.failedLookup,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toJson() => {
        'normalizedTitle': normalizedTitle,
        'year': year,
        'youtubeId': youtubeId,
        'source': source,
        'failedLookup': failedLookup,
        'createdAtMillis': createdAtMillis,
      };

  factory TrailerCacheEntry.fromJson(Map<String, dynamic> json) {
    return TrailerCacheEntry(
      normalizedTitle: json['normalizedTitle']?.toString() ?? '',
      year: json['year']?.toString(),
      youtubeId: json['youtubeId']?.toString(),
      source: json['source']?.toString() ?? 'none',
      failedLookup: json['failedLookup'] as bool? ?? false,
      createdAtMillis: json['createdAtMillis'] as int? ?? 0,
    );
  }

  bool isExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ageMs = now - createdAtMillis;
    if (failedLookup) {
      // Failed lookups expire after 7 days
      const failedTtl = 7 * 24 * 60 * 60 * 1000;
      return ageMs > failedTtl;
    } else {
      // Successful lookups expire after 60 days (within the 30-90 range)
      const successTtl = 60 * 24 * 60 * 60 * 1000;
      return ageMs > successTtl;
    }
  }
}

class TrailerCacheService {
  static final _storage = GetStorage("youtube_trailer_cache");

  static String _buildKey(String title, String? year) {
    final cleanTitle = title.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final cleanYear = year?.trim() ?? '';
    return cleanYear.isNotEmpty ? "$cleanTitle|$cleanYear" : cleanTitle;
  }

  /// Retrieves a valid non-expired trailer cache entry
  static TrailerCacheEntry? getEntry(String title, String? year) {
    try {
      final key = _buildKey(title, year);
      final rawData = _storage.read(key);
      if (rawData == null) return null;

      // Handle raw JSON Map conversion safely
      if (rawData is Map) {
        final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(rawData);
        final entry = TrailerCacheEntry.fromJson(jsonMap);
        if (entry.isExpired()) {
          log("[TRAILER_CACHE] Expired entry found for key: $key. Evicting.");
          _storage.remove(key);
          return null;
        }
        return entry;
      }
      return null;
    } catch (e) {
      log("[TRAILER_CACHE] Error reading cache entry: $e");
      return null;
    }
  }

  /// Writes a success or failure entry to the local trailer cache
  static void writeEntry({
    required String title,
    String? year,
    String? youtubeId,
    required String source,
    required bool failedLookup,
  }) {
    try {
      final key = _buildKey(title, year);
      final entry = TrailerCacheEntry(
        normalizedTitle: title.toLowerCase().trim(),
        year: year,
        youtubeId: youtubeId,
        source: source,
        failedLookup: failedLookup,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );

      _storage.write(key, entry.toJson());
      log("[TRAILER_CACHE] Cache write successful for key '$key' (failed=$failedLookup, id=$youtubeId)");
    } catch (e) {
      log("[TRAILER_CACHE] Error writing cache entry: $e");
    }
  }

  /// Evicts a specific key from the cache if needed
  static void removeEntry(String title, String? year) {
    final key = _buildKey(title, year);
    _storage.remove(key);
  }
}
