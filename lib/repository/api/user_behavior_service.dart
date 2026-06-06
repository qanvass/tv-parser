import 'package:flutter/foundation.dart';
import '../models/user_preference_profile.dart';

class UserBehaviorService {
  /// Records a channel/movie/series click to update learned preferences
  static Future<void> trackClick(String itemId, String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return;

    try {
      final profile = UserPreferenceProfile.load();
      final clicks = Map<String, int>.from(profile.categoryClicks);
      
      clicks[categoryId] = (clicks[categoryId] ?? 0) + 1;
      
      final updated = profile.copyWith(categoryClicks: clicks);
      await updated.save();
      
      debugPrint("[TV_PARSER_BEHAVIOR] Tracked Click on Item: $itemId | Category: $categoryId | Total clicks: ${clicks[categoryId]}");
    } catch (e) {
      debugPrint("Error tracking behavior click: $e");
    }
  }

  /// Records play duration. Plays > 2 mins boost categories; quick exits < 15s penalize categories.
  static Future<void> trackPlay(String itemId, String? categoryId, int durationSeconds) async {
    if (categoryId == null || categoryId.isEmpty) return;

    try {
      final profile = UserPreferenceProfile.load();
      final clicks = Map<String, int>.from(profile.categoryClicks);
      final watchHistory = List<String>.from(profile.recentWatchHistory);

      // Add to watch history
      if (!watchHistory.contains(itemId)) {
        watchHistory.insert(0, itemId);
        if (watchHistory.length > 30) {
          watchHistory.removeLast(); // Keep size bounded
        }
      }

      if (durationSeconds >= 120) {
        // High engagement: learned preference boost!
        clicks[categoryId] = (clicks[categoryId] ?? 0) + 5;
        debugPrint("[TV_PARSER_BEHAVIOR] High Engagement on Item: $itemId | Boosted Category: $categoryId (+5 clicks)");
      } else if (durationSeconds <= 15 && durationSeconds > 0) {
        // Quick exit / skip: penalize category slightly to hide uninteresting content
        final current = clicks[categoryId] ?? 0;
        clicks[categoryId] = current > 3 ? current - 3 : 0;
        debugPrint("[TV_PARSER_BEHAVIOR] Quick Exit on Item: $itemId | Penalized Category: $categoryId (-3 clicks)");
      }

      final updated = profile.copyWith(
        categoryClicks: clicks,
        recentWatchHistory: watchHistory,
      );
      await updated.save();
    } catch (e) {
      debugPrint("Error tracking behavior play: $e");
    }
  }

  /// Records search queries to learn user term preferences
  static Future<void> trackSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final profile = UserPreferenceProfile.load();
      final searches = List<String>.from(profile.lastSearches);
      final clean = query.trim().toLowerCase();

      if (!searches.contains(clean)) {
        searches.insert(0, clean);
        if (searches.length > 15) {
          searches.removeLast();
        }
      }

      final updated = profile.copyWith(lastSearches: searches);
      await updated.save();
      
      debugPrint("[TV_PARSER_BEHAVIOR] Tracked Search: $clean");
    } catch (e) {
      debugPrint("Error tracking behavior search: $e");
    }
  }
}
