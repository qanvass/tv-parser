import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import '../models/user_preference_profile.dart';
import '../models/category.dart';

class ContentIntelligenceService {
  static double scoreLive(
      ChannelLive item, UserPreferenceProfile profile, Map<String, String> categoryIdToName) {
    double score = 0;

    final String nameLower = (item.name ?? '').toLowerCase();

    // Category Name matching
    final String? categoryName = item.categoryId != null ? categoryIdToName[item.categoryId] : null;

    final String catNameLower = (categoryName ?? '').toLowerCase();

    // 1. Language preference score
    if (profile.language != null) {
      final langLower = profile.language!.toLowerCase();
      if (nameLower.contains(langLower) || catNameLower.contains(langLower)) {
        score += 40;
      }
    }

    // 2. Region / Country preference score
    if (profile.country != null) {
      final countryLower = profile.country!.toLowerCase();
      if (nameLower.contains(countryLower) || catNameLower.contains(countryLower)) {
        score += 50;
      }
    }
    if (profile.region != null) {
      final regionLower = profile.region!.toLowerCase();
      if (nameLower.contains(regionLower) || catNameLower.contains(regionLower)) {
        score += 25;
      }
    }

    // 3. Match preferred categories & genres
    if (profile.preferredCategories.contains(item.categoryId)) {
      score += 30;
    }

    // 4. Match historical favorites & watch history
    if (item.streamId != null && profile.favorites.contains(item.streamId!)) {
      score += 100;
    }
    if (item.streamId != null && profile.recentWatchHistory.contains(item.streamId!)) {
      score += 20;
    }

    // 5. General Smart Boosters (USA, English, Local, Sports)
    if (nameLower.contains('usa') ||
        catNameLower.contains('usa') ||
        nameLower.contains('us') ||
        catNameLower.contains('us')) {
      score += 20;
    }
    if (nameLower.contains('english') ||
        catNameLower.contains('english') ||
        nameLower.contains(' en ') ||
        catNameLower.contains(' en ')) {
      score += 20;
    }
    if (nameLower.contains('local') || catNameLower.contains('local')) {
      score += 15;
    }
    if (nameLower.contains('sports') ||
        catNameLower.contains('sports') ||
        nameLower.contains('sport') ||
        catNameLower.contains('sport')) {
      score += 10;
    }

    return score;
  }

  static double scoreMovie(
      ChannelMovie item, UserPreferenceProfile profile, Map<String, String> categoryIdToName) {
    double score = 0;

    final String nameLower = (item.name ?? '').toLowerCase();

    final String? categoryName = item.categoryId != null ? categoryIdToName[item.categoryId] : null;
    final String catNameLower = (categoryName ?? '').toLowerCase();

    if (profile.language != null) {
      final langLower = profile.language!.toLowerCase();
      if (nameLower.contains(langLower) || catNameLower.contains(langLower)) {
        score += 40;
      }
    }

    if (profile.country != null) {
      final countryLower = profile.country!.toLowerCase();
      if (nameLower.contains(countryLower) || catNameLower.contains(countryLower)) {
        score += 50;
      }
    }

    if (profile.preferredCategories.contains(item.categoryId)) {
      score += 30;
    }

    if (item.streamId != null && profile.favorites.contains(item.streamId!)) {
      score += 100;
    }
    if (item.streamId != null && profile.recentWatchHistory.contains(item.streamId!)) {
      score += 20;
    }

    if (nameLower.contains('usa') ||
        catNameLower.contains('usa') ||
        nameLower.contains('us') ||
        catNameLower.contains('us')) {
      score += 20;
    }
    if (nameLower.contains('english') || catNameLower.contains('english')) {
      score += 20;
    }

    // Boost based on Movie Rating
    if (item.rating != null) {
      final r = double.tryParse(item.rating!);
      if (r != null) {
        score += r * 2.0; // rating based boost (e.g. 8.5/10 -> +17)
      }
    }

    return score;
  }

  static double scoreSerie(
      ChannelSerie item, UserPreferenceProfile profile, Map<String, String> categoryIdToName) {
    double score = 0;

    final String nameLower = (item.name ?? '').toLowerCase();

    final String? categoryName = item.categoryId != null ? categoryIdToName[item.categoryId] : null;
    final String catNameLower = (categoryName ?? '').toLowerCase();

    if (profile.language != null) {
      final langLower = profile.language!.toLowerCase();
      if (nameLower.contains(langLower) || catNameLower.contains(langLower)) {
        score += 40;
      }
    }

    if (profile.country != null) {
      final countryLower = profile.country!.toLowerCase();
      if (nameLower.contains(countryLower) || catNameLower.contains(countryLower)) {
        score += 50;
      }
    }

    if (profile.preferredCategories.contains(item.categoryId)) {
      score += 30;
    }

    if (item.seriesId != null && profile.favorites.contains(item.seriesId!)) {
      score += 100;
    }
    if (item.seriesId != null && profile.recentWatchHistory.contains(item.seriesId!)) {
      score += 20;
    }

    if (nameLower.contains('usa') ||
        catNameLower.contains('usa') ||
        nameLower.contains('us') ||
        catNameLower.contains('us')) {
      score += 20;
    }
    if (nameLower.contains('english') || catNameLower.contains('english')) {
      score += 20;
    }

    if (item.rating != null) {
      final r = double.tryParse(item.rating!);
      if (r != null) {
        score += r * 2.0;
      }
    }

    return score;
  }

  /// Sorts by score, highest first, scoring each item exactly once.
  /// The old comparator re-scored both items on every comparison
  /// (~2·n·log n string scans) which stalled the UI thread on large shelves.
  /// Ties keep their incoming order (stable).
  static List<T> _sortByScoreDesc<T>(List<T> items, double Function(T) score) {
    final scores = List<double>.generate(items.length, (i) => score(items[i]));
    final order = List<int>.generate(items.length, (i) => i);
    order.sort((a, b) {
      final c = scores[b].compareTo(scores[a]);
      return c != 0 ? c : a.compareTo(b);
    });
    return [for (final i in order) items[i]];
  }

  static List<ChannelLive> sortLives(
      List<ChannelLive> items, UserPreferenceProfile profile, List<CategoryModel> categories) {
    final sorted = List<ChannelLive>.from(items);
    final categoryIdToName = {
      for (final cat in categories)
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!
    };
    return _sortByScoreDesc(
      sorted,
      (item) => scoreLive(item, profile, categoryIdToName),
    );
  }

  static List<ChannelMovie> sortMovies(
      List<ChannelMovie> items, UserPreferenceProfile profile, List<CategoryModel> categories) {
    final sorted = List<ChannelMovie>.from(items);
    final categoryIdToName = {
      for (final cat in categories)
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!
    };
    return _sortByScoreDesc(
      sorted,
      (item) => scoreMovie(item, profile, categoryIdToName),
    );
  }

  static List<ChannelSerie> sortSeries(
      List<ChannelSerie> items, UserPreferenceProfile profile, List<CategoryModel> categories) {
    final sorted = List<ChannelSerie>.from(items);
    final categoryIdToName = {
      for (final cat in categories)
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!
    };
    return _sortByScoreDesc(
      sorted,
      (item) => scoreSerie(item, profile, categoryIdToName),
    );
  }

  // ─── Presentational Content Guards & Classifiers [NEW] ─────────────────────

  /// Returns true if the item is classified as a Live TV channel or Live feed
  static bool isLiveChannel(dynamic item, {String? categoryName}) {
    if (item is ChannelLive) {
      // Primary source list is Live, so it's live by default.
      // Sanitize obvious mistakes (e.g. pure VOD categories erroneously placed in Live)
      final String catLower = (categoryName ?? '').toLowerCase();
      if (catLower.contains('vod movie') || catLower.contains('pure vod') || catLower.contains('netflix series')) {
        return false;
      }
      return true;
    }
    
    if (item is ChannelMovie) {
      if (item.streamType == 'live') {
        return true;
      }
    }
    
    // Fallback keyword check
    final String nameLower = (item.name ?? '').toLowerCase();
    final String catLower = (categoryName ?? '').toLowerCase();
    
    if (nameLower.contains(' live') || nameLower.startsWith('live ') || nameLower == 'live') {
      return true;
    }
    
    if (catLower.contains('live tv') || catLower.contains('live channels') || catLower.contains('tv en vivo')) {
      return true;
    }
    
    return false;
  }

  /// Returns true only if it is a legitimate VOD Movie record
  static bool isMovieVOD(dynamic item, {String? categoryName}) {
    if (item is! ChannelMovie) {
      return false;
    }
    
    // Primary source list is Movie VOD.
    // Clean up obvious live feeds, news, and sports channels bleeding in.
    if (item.streamType == 'live') {
      return false;
    }
    
    final String nameLower = (item.name ?? '').toLowerCase();
    final String catLower = (categoryName ?? '').toLowerCase();
    
    // Reject live TV/news category bleed
    if (catLower.contains('live tv') || catLower.contains('live channels') || nameLower.contains('live channel')) {
      return false;
    }
    
    // Reject sports categories or channels bleeding into movies (e.g., live sports streams labeled as VOD)
    if (isSportsEvent(item, categoryName: categoryName)) {
      // If it looks like a live feed/stream or channel, reject from VOD Movie row
      if (nameLower.contains('live') || nameLower.contains('stream') || nameLower.contains('ch ') || nameLower.contains('tv')) {
        return false;
      }
    }
    
    // Reject news streams bleeding into movie lists
    if (nameLower.contains('cnn') || nameLower.contains('nbc news') || nameLower.contains('fox news') || nameLower.contains('bbc news')) {
      return false;
    }
    
    return true;
  }

  /// Returns true only if it is a Series item
  static bool isSeriesVOD(dynamic item) {
    return item is ChannelSerie;
  }

  /// Checks if the stream contains sports keywords or is in a sports category
  static bool isSportsEvent(dynamic item, {String? categoryName}) {
    final String nameLower = (item.name ?? '').toLowerCase();
    final String catLower = (categoryName ?? '').toLowerCase();
    
    final sportsKeywords = [
      'sport', 'sports', 'espn', 'sky sports', 'fox sports', 'nfl', 'nba', 'mlb', 'ufc', 
      'fight', 'wwe', 'racing', 'formula 1', 'f1', 'motogp', 'soccer', 'football', 
      'tennis', 'golf', 'cricket', 'olympics', 'world cup', 'bein sports', 'formulaone',
      'grand prix', 'nascar', 'bundesliga', 'laliga', 'premier league', 'champions league'
    ];
    
    for (final kw in sportsKeywords) {
      if (nameLower.contains(kw) || catLower.contains(kw)) {
        return true;
      }
    }
    
    return false;
  }

  /// Suppresses duplicate items by ID or Title for presentational rows
  static List<T> deduplicate<T>(List<T> items, String Function(T) getId) {
    final Set<String> seen = {};
    final List<T> uniqueList = [];
    
    for (final item in items) {
      final id = getId(item).trim().toLowerCase();
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        uniqueList.add(item);
      }
    }
    
    return uniqueList;
  }
}

