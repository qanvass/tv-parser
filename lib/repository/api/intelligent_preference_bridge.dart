import 'package:flutter/foundation.dart';

import '../models/user_preference_profile.dart';

/// Keeps UserPreferenceProfile in sync with FavoriteLocale / WatchingLocale
/// so ContentIntelligenceService and RowCurationService score favorites correctly.
class IntelligentPreferenceBridge {
  static Future<void> syncFavoriteId({
    required String id,
    required bool isAdd,
  }) async {
    if (id.isEmpty) return;
    try {
      final profile = UserPreferenceProfile.load();
      final favorites = List<String>.from(profile.favorites);
      if (isAdd) {
        if (!favorites.contains(id)) {
          favorites.insert(0, id);
          if (favorites.length > 200) favorites.removeLast();
        }
      } else {
        favorites.remove(id);
      }
      await profile.copyWith(favorites: favorites).save();
      debugPrint(
        '[PreferenceBridge] favorite ${isAdd ? "add" : "remove"} id=$id',
      );
    } catch (e) {
      debugPrint('[PreferenceBridge] syncFavoriteId error: $e');
    }
  }

  /// Rebuilds profile.favorites from stored favorite lists (app boot).
  static Future<void> rebuildFavoritesFromStorage({
    required List<String> liveIds,
    required List<String> movieIds,
    required List<String> seriesIds,
  }) async {
    try {
      final merged = <String>[
        ...liveIds,
        ...movieIds,
        ...seriesIds,
      ].where((id) => id.isNotEmpty).toSet().toList();
      final profile = UserPreferenceProfile.load();
      await profile.copyWith(favorites: merged).save();
      debugPrint(
        '[PreferenceBridge] rebuilt ${merged.length} favorite IDs',
      );
    } catch (e) {
      debugPrint('[PreferenceBridge] rebuild error: $e');
    }
  }

  static Future<void> syncRecentWatchId(String id) async {
    if (id.isEmpty) return;
    try {
      final profile = UserPreferenceProfile.load();
      final history = List<String>.from(profile.recentWatchHistory);
      history.remove(id);
      history.insert(0, id);
      if (history.length > 30) history.removeLast();
      await profile.copyWith(recentWatchHistory: history).save();
    } catch (e) {
      debugPrint('[PreferenceBridge] syncRecentWatchId error: $e');
    }
  }
}
