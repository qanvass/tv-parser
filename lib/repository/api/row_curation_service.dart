import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import '../models/user_preference_profile.dart';
import '../models/ranked_item.dart';
import '../models/premium_plus_item.dart';
import 'content_intelligence_service.dart';
import 'premium_plus_service.dart';
import 'provider_curation_rules.dart';

const List<String> theaterHeroTargets = [
  'Masters of the Universe',
  'Scary Movie',
  'Scary Movie 6',
  'Backrooms',
  'Obsession',
  'Star Wars: The Mandalorian and Grogu',
  'The Mandalorian and Grogu',
  'Michael',
  'The Breadwinner',
  'The Devil Wears Prada 2',
  'Pressure',
  'Power Ballad',
];

class RowCurationService {
  /// Tracks global deduplication across rows during a single curation pass
  final Set<String> _curatedIds = {};

  /// Logs explanatory item details for QA sprints
  void _logQAExplanation(RankedItem ranked) {
    if (kDebugMode) {
      debugPrint(
        "[TV_PARSER_REC_QA] Row: ${ranked.sourceRow.toUpperCase()} | "
        "Type: ${ranked.contentType.toUpperCase()} | "
        "Title: ${RankedItem.getItemTitle(ranked.item)} | "
        "Score: ${ranked.score.toStringAsFixed(1)} | "
        "Confidence: ${(ranked.confidence * 100).toStringAsFixed(0)}% | "
        "Reasons: ${ranked.reasons.join(', ')}"
      );
    }
  }

  String _normalizeTitle(String title) {
    String text = title.toLowerCase();

    // Remove common prefixes
    final prefixes = [
      r'^\s*top\s*-\s*',
      r'^\s*nf\s*-\s*',
      r'^\s*cam\s*-\s*',
      r'^\s*hd\s*-\s*',
      r'^\s*fhd\s*-\s*',
      r'^\s*4k\s*-\s*',
      r'^\s*usa\s*-\s*',
      r'^\s*us\s*-\s*',
      r'^\s*uk\s*-\s*',
    ];
    for (final p in prefixes) {
      text = text.replaceFirst(RegExp(p), '');
    }

    // Remove year tags like (2026), [2026], etc.
    text = text.replaceAll(RegExp(r'[\(\[\{]\s*\d{4}\s*[\)\]\}]'), '');

    // Remove country/quality tags
    final tags = [
      r'\b(us|usa|in|uk|ca|canada|english|en|es|espanol)\b',
      r'\b(hd|fhd|uhd|4k|2k|1080p|720p|480p|sd|web-dl|webdl|web|hdtv|bluray|brrip|dvdrip|dvd|cam|hdcam|ts|tc|hc|telesync)\b',
    ];
    for (final t in tags) {
      text = text.replaceAll(RegExp(t), '');
    }

    // Trim punctuation and extra spaces
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' '); // replace punctuation with space
    text = text.replaceAll(RegExp(r'\s+'), ' '); // collapse spaces
    return text.trim();
  }

  String? _getMatchedTargetCanonical(String normalizedProvider) {
    if (normalizedProvider.contains("masters of the universe")) return "Masters of the Universe";
    if (normalizedProvider.contains("scary movie")) return "Scary Movie";
    if (normalizedProvider.contains("backrooms")) return "Backrooms";
    if (normalizedProvider.contains("obsession")) return "Obsession";
    if (normalizedProvider.contains("mandalorian and grogu")) return "The Mandalorian and Grogu";
    if (normalizedProvider.contains("michael")) return "Michael";
    if (normalizedProvider.contains("the breadwinner")) return "The Breadwinner";
    if (normalizedProvider.contains("the devil wears prada 2") || (normalizedProvider.contains("devil") && normalizedProvider.contains("wears") && normalizedProvider.contains("prada") && normalizedProvider.contains("2"))) return "The Devil Wears Prada 2";
    if (normalizedProvider.contains("pressure")) return "Pressure";
    if (normalizedProvider.contains("power ballad")) return "Power Ballad";
    return null;
  }

  int _getQualityScore(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('4k') || lower.contains('uhd') || lower.contains('2160p')) return 100;
    if (lower.contains('fhd') || lower.contains('1080p')) return 90;
    if (lower.contains('hd') || lower.contains('720p')) return 80;
    if (lower.contains('web-dl') || lower.contains('webdl') || lower.contains('web')) return 70;
    if (lower.contains('sd') || lower.contains('480p') || lower.contains('576p')) return 50;
    if (lower.contains('cam') || lower.contains('hdcam') || lower.contains('ts') || lower.contains('tc') || lower.contains('telesync')) return 10;
    return 60; // Default average quality
  }

  /// 1. buildHeroItems()
  /// Curates 8-10 visually strong, premium theatrical/popular hero items.
  /// Exactly 1 live channel and 8-9 VOD movies.
  List<RankedItem<ChannelMovie>> buildHeroItems(
    List<ChannelMovie> allMovies,
    List<ChannelSerie> allSeries,
    List<ChannelLive> allLives,
    UserPreferenceProfile profile,
    Map<String, String> categoryIdToName,
  ) {
    // 1. Group movie matches from theaterHeroTargets
    final Map<String, ChannelMovie> targetBestMatches = {};
    final Map<String, int> targetBestScores = {};

    for (final m in allMovies) {
      final catName = categoryIdToName[m.categoryId] ?? '';
      if (!ContentIntelligenceService.isMovieVOD(m, categoryName: catName)) continue;
      if (ProviderCurationRules.isAdultCategory(m.name ?? '') || ProviderCurationRules.isAdultCategory(catName)) continue;

      final normalizedTitle = _normalizeTitle(m.name ?? '');
      final matchedTarget = _getMatchedTargetCanonical(normalizedTitle);

      if (matchedTarget != null) {
        final qScore = _getQualityScore(m.name ?? '');
        final existingScore = targetBestScores[matchedTarget];
        if (existingScore == null || qScore > existingScore) {
          targetBestScores[matchedTarget] = qScore;
          targetBestMatches[matchedTarget] = m;
        }
      }
    }

    final List<ChannelMovie> heroMoviesList = [];
    final Set<String> curatedMovieTitles = {};
    final Set<String> curatedMovieIds = {};

    targetBestMatches.forEach((target, movie) {
      heroMoviesList.add(movie);
      curatedMovieTitles.add(_normalizeTitle(movie.name ?? ''));
      curatedMovieIds.add(movie.streamId ?? '');
    });

    final int targetMovieCount = targetBestMatches.length >= 9 ? 9 : 8;

    // 2. Fallback movie logic: Fill remaining movie slots if targetMovieCount is not reached
    if (heroMoviesList.length < targetMovieCount) {
      final List<RankedItem<ChannelMovie>> fallbackCandidates = [];
      for (final m in allMovies) {
        final id = m.streamId ?? '';
        if (curatedMovieIds.contains(id)) continue;
        final catName = categoryIdToName[m.categoryId] ?? '';
        if (!ContentIntelligenceService.isMovieVOD(m, categoryName: catName)) continue;
        if (ProviderCurationRules.isAdultCategory(m.name ?? '') || ProviderCurationRules.isAdultCategory(catName)) continue;

        final normalized = _normalizeTitle(m.name ?? '');
        if (curatedMovieTitles.contains(normalized)) continue;

        double score = ContentIntelligenceService.scoreMovie(m, profile, categoryIdToName);
        score += _getQualityScore(m.name ?? '');

        // Fallback keywords boosts
        final nameLower = (m.name ?? '').toLowerCase();
        final catLower = catName.toLowerCase();
        final boostKeywords = ['new', 'recently added', '2026', 'top', 'trending', 'box office', 'cinema', 'theater', 'theatrical'];
        for (final keyword in boostKeywords) {
          if (nameLower.contains(keyword) || catLower.contains(keyword)) {
            score += 40.0;
          }
        }

        fallbackCandidates.add(RankedItem<ChannelMovie>(
          item: m,
          score: score,
          confidence: 0.85,
          reasons: ["Personalized VOD pick"],
          contentType: 'movie',
          sourceRow: 'hero_carousel',
        ));
      }

      fallbackCandidates.sort((a, b) => b.score.compareTo(a.score));
      for (final c in fallbackCandidates) {
        if (heroMoviesList.length >= targetMovieCount) break;
        final normalized = _normalizeTitle(c.item.name ?? '');
        if (curatedMovieTitles.contains(normalized)) continue;

        heroMoviesList.add(c.item);
        curatedMovieTitles.add(normalized);
        curatedMovieIds.add(c.item.streamId ?? '');
      }
    }

    // 3. Select exactly one Live hero item
    double highestLiveScore = -99999;
    ChannelLive? bestLiveChannel;

    for (final l in allLives) {
      final catName = categoryIdToName[l.categoryId] ?? '';
      if (ProviderCurationRules.isAdultCategory(l.name ?? '') || ProviderCurationRules.isAdultCategory(catName)) continue;

      double score = ContentIntelligenceService.scoreLive(l, profile, categoryIdToName);
      
      final nameLower = (l.name ?? '').toLowerCase();
      final catLower = catName.toLowerCase();

      final liveKeywords = [
        'espn', 'fox', 'abc', 'cbs', 'nbc', 'tnt', 'tbs', 'fs1', 'nfl', 'nba', 'mlb', 'sports', 'local news', 'news', 'breaking news'
      ];

      for (final kw in liveKeywords) {
        if (nameLower.contains(kw) || catLower.contains(kw)) {
          score += 50.0;
        }
      }

      if (catLower.contains('usa') || catLower.contains('united states') || catLower.contains('us') || catLower.contains('uk') || catLower.contains('canada') || catLower.contains('english')) {
        score += 30.0;
      }

      if (profile.region != null && profile.region!.isNotEmpty) {
        final regLower = profile.region!.toLowerCase();
        if (nameLower.contains(regLower) || catLower.contains(regLower)) {
          score += 100.0;
        }

        final isAtlantaUser = regLower.contains('atlanta') || regLower.contains('georgia') || regLower == 'ga';
        if (isAtlantaUser && ProviderCurationRules.isAtlantaLocal(l.name ?? '')) {
          score += 150.0;
        }
      }

      if (nameLower.contains('espn usa hd') || nameLower.contains('espn usa')) {
        score += 10.0;
      }

      if (score > highestLiveScore) {
        highestLiveScore = score;
        bestLiveChannel = l;
      }
    }

    ChannelMovie? liveHeroMovie;
    if (bestLiveChannel != null) {
      liveHeroMovie = ChannelMovie(
        streamId: bestLiveChannel.streamId,
        name: bestLiveChannel.name,
        streamIcon: bestLiveChannel.streamIcon,
        rating: "9.0",
        customSid: "live",
        categoryId: bestLiveChannel.categoryId,
      );
    }

    // 4. Combine Live and Movie items, applying placement logic
    final List<ChannelMovie> finalCarouselItems = [];

    // Add movies
    finalCarouselItems.addAll(heroMoviesList.take(targetMovieCount));

    // Live placement: If live is strongest (highest score overall), place at index 0
    // Otherwise place it between index 1 and 2 (never below index 2 to stay within first 3 slides)
    if (liveHeroMovie != null) {
      final double liveActualScore = highestLiveScore + 60.0; // live hero priority boost
      double highestMovieScore = -99999;
      if (heroMoviesList.isNotEmpty) {
        highestMovieScore = ContentIntelligenceService.scoreMovie(heroMoviesList.first, profile, categoryIdToName);
      }

      if (liveActualScore >= highestMovieScore || finalCarouselItems.isEmpty) {
        finalCarouselItems.insert(0, liveHeroMovie);
      } else {
        final int insertPos = min(2, finalCarouselItems.length);
        finalCarouselItems.insert(insertPos, liveHeroMovie);
      }
    }

    // 5. Emergency Series fallback if total carousel items is under 6
    if (finalCarouselItems.length < 6 && allSeries.isNotEmpty) {
      final List<RankedItem<ChannelSerie>> seriesCandidates = [];
      for (final s in allSeries) {
        if (!ContentIntelligenceService.isSeriesVOD(s)) continue;
        if (ProviderCurationRules.isAdultCategory(s.name ?? '') || ProviderCurationRules.isAdultCategory(categoryIdToName[s.categoryId] ?? '')) continue;
        
        final score = ContentIntelligenceService.scoreSerie(s, profile, categoryIdToName);
        seriesCandidates.add(RankedItem<ChannelSerie>(
          item: s,
          score: score,
          confidence: 0.8,
          reasons: ["Personalized VOD Series pick"],
          contentType: 'series',
          sourceRow: 'hero_carousel',
        ));
      }

      seriesCandidates.sort((a, b) => b.score.compareTo(a.score));

      for (final c in seriesCandidates) {
        if (finalCarouselItems.length >= 8) break; // target 8 total items minimum
        final mappedMovie = ChannelMovie(
          streamId: c.item.seriesId,
          name: c.item.name,
          streamIcon: c.item.cover,
          rating: c.item.rating,
          customSid: 'series',
          categoryId: c.item.categoryId,
        );
        finalCarouselItems.add(mappedMovie);
      }
    }

    // 6. Safe debug logs
    if (kDebugMode) {
      debugPrint('[HERO_CAROUSEL_CURATION] Theatrical targets matched count: ${targetBestMatches.length}');
      debugPrint('[HERO_CAROUSEL_CURATION] Matched titles: ${targetBestMatches.keys.join(", ")}');
      debugPrint('[HERO_CAROUSEL_CURATION] Selected Live Hero: ${bestLiveChannel?.name ?? "None"}');
      debugPrint('[HERO_CAROUSEL_CURATION] Final Hero Carousel Count: ${finalCarouselItems.length}');
    }

    // 7. Convert to RankedItem list
    final List<RankedItem<ChannelMovie>> results = [];
    for (final item in finalCarouselItems) {
      results.add(RankedItem<ChannelMovie>(
        item: item,
        score: item.customSid == 'live' ? highestLiveScore : 100.0,
        confidence: 0.9,
        reasons: ["Personalized Hero Pick"],
        contentType: item.customSid ?? 'movie',
        sourceRow: 'hero_carousel',
      ));
    }
    return results;
  }

  /// 2. buildTrendingMovies()
  /// Strictly VOD Movies only.
  List<ChannelMovie> buildTrendingMovies(
    List<ChannelMovie> allMovies,
    UserPreferenceProfile profile,
    Map<String, String> categoryIdToName,
  ) {
    final List<RankedItem<ChannelMovie>> ranked = [];

    for (final m in allMovies) {
      final id = m.streamId ?? '';
      if (_curatedIds.contains(id)) continue; // Deduplication
      final catName = categoryIdToName[m.categoryId] ?? '';
      if (!ContentIntelligenceService.isMovieVOD(m, categoryName: catName)) continue;

      double score = ContentIntelligenceService.scoreMovie(m, profile, categoryIdToName);
      final reasons = ["True VOD movie stream", "No live bleed"];

      // Boost premium artwork
      if (m.streamIcon != null && m.streamIcon!.isNotEmpty) {
        score += 10;
        reasons.add("Visual layout optimization (valid cover image)");
      }

      ranked.add(RankedItem<ChannelMovie>(
        item: m,
        score: score,
        confidence: 0.85,
        reasons: reasons,
        contentType: 'movie',
        sourceRow: 'trending_movies',
      ));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    
    final List<ChannelMovie> results = [];
    for (final r in ranked.take(15)) {
      results.add(r.item);
      _curatedIds.add(r.item.streamId ?? '');
      _logQAExplanation(r);
    }
    return results;
  }

  /// 3. buildFeaturedSeries()
  /// Strictly VOD Series only.
  List<ChannelSerie> buildFeaturedSeries(
    List<ChannelSerie> allSeries,
    UserPreferenceProfile profile,
    Map<String, String> categoryIdToName,
  ) {
    final List<RankedItem<ChannelSerie>> ranked = [];

    for (final s in allSeries) {
      final id = s.seriesId ?? '';
      if (_curatedIds.contains(id)) continue; // Deduplication
      if (!ContentIntelligenceService.isSeriesVOD(s)) continue;

      double score = ContentIntelligenceService.scoreSerie(s, profile, categoryIdToName);
      final reasons = ["Validated VOD Series catalog"];

      ranked.add(RankedItem<ChannelSerie>(
        item: s,
        score: score,
        confidence: 0.88,
        reasons: reasons,
        contentType: 'series',
        sourceRow: 'featured_series',
      ));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));

    final List<ChannelSerie> results = [];
    for (final r in ranked.take(15)) {
      results.add(r.item);
      _curatedIds.add(r.item.seriesId ?? '');
      _logQAExplanation(r);
    }
    return results;
  }

  /// 4. buildUsaSports()
  /// Strictly live sports channels / events.
  List<ChannelLive> buildUsaSports(
    List<ChannelLive> allLives,
    UserPreferenceProfile profile,
    Map<String, String> categoryIdToName,
  ) {
    final List<RankedItem<ChannelLive>> ranked = [];

    for (final l in allLives) {
      final id = l.streamId ?? '';
      if (_curatedIds.contains(id)) continue;
      final catName = categoryIdToName[l.categoryId] ?? '';
      if (!ContentIntelligenceService.isSportsEvent(l, categoryName: catName)) continue;

      double score = ContentIntelligenceService.scoreLive(l, profile, categoryIdToName);
      final reasons = ["Classified as live sports broadcast"];

      // Premium sport brand boosts
      final nameLower = (l.name ?? '').toLowerCase();
      if (nameLower.contains('espn')) {
        score += 80;
        reasons.add("ESPN premium sports network boost");
      } else if (nameLower.contains('fox sports') || nameLower.contains('fox sport')) {
        score += 70;
        reasons.add("Fox Sports prime network boost");
      } else if (nameLower.contains('bein')) {
        score += 60;
        reasons.add("BeIN Sports broadcast boost");
      }

      ranked.add(RankedItem<ChannelLive>(
        item: l,
        score: score,
        confidence: 0.95,
        reasons: reasons,
        contentType: 'live',
        sourceRow: 'usa_sports',
      ));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));

    final List<ChannelLive> results = [];
    for (final r in ranked.take(15)) {
      results.add(r.item);
      _curatedIds.add(r.item.streamId ?? '');
      _logQAExplanation(r);
    }
    return results;
  }

  /// 5. buildLocalNews()
  /// News and local channels.
  List<ChannelLive> buildLocalNews(
    List<ChannelLive> allLives,
    UserPreferenceProfile profile,
    Map<String, String> categoryIdToName,
  ) {
    final List<RankedItem<ChannelLive>> ranked = [];

    for (final l in allLives) {
      final id = l.streamId ?? '';
      if (_curatedIds.contains(id)) continue;

      final nameLower = (l.name ?? '').toLowerCase();
      final isNews = nameLower.contains('news') || 
                     nameLower.contains('cnn') || 
                     nameLower.contains('bbc') || 
                     nameLower.contains('cbs') ||
                     nameLower.contains('nbc') ||
                     nameLower.contains('abc') ||
                     nameLower.contains('fox news') ||
                     nameLower.contains('local') ||
                     (profile.region != null && nameLower.contains(profile.region!.toLowerCase()));

      if (!isNews) continue;

      double score = ContentIntelligenceService.scoreLive(l, profile, categoryIdToName);
      final reasons = ["Live local or national news network"];

      if (nameLower.contains('cnn') || nameLower.contains('bbc') || nameLower.contains('fox news')) {
        score += 50;
        reasons.add("Major breaking news boost");
      }
      if (profile.region != null) {
        final regLower = profile.region!.toLowerCase();
        if (nameLower.contains(regLower)) {
          score += 80;
          reasons.add("Local state/city alignment: ${profile.region}");
        }

        final isAtlantaUser = regLower.contains('atlanta') || regLower.contains('georgia') || regLower == 'ga';
        if (isAtlantaUser && ProviderCurationRules.isAtlantaLocal(l.name ?? '')) {
          score += 100.0;
          reasons.add("Atlanta Local News priority boost");
        }
      }

      ranked.add(RankedItem<ChannelLive>(
        item: l,
        score: score,
        confidence: 0.90,
        reasons: reasons,
        contentType: 'live',
        sourceRow: 'local_news',
      ));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));

    final List<ChannelLive> results = [];
    for (final r in ranked.take(12)) {
      results.add(r.item);
      _curatedIds.add(r.item.streamId ?? '');
      _logQAExplanation(r);
    }
    return results;
  }

  /// 6. buildConciergePicks()
  /// Highly-curated For You picks mixing live and VOD with relevance explanations.
  List<RankedItem<dynamic>> buildConciergePicks(
    List<ChannelLive> allLives,
    List<ChannelMovie> allMovies,
    List<ChannelSerie> allSeries,
    UserPreferenceProfile profile,
    Map<String, String> categoryIdToName,
  ) {
    final List<RankedItem<dynamic>> candidates = [];

    // Add Live candidates
    for (final l in allLives) {
      final id = l.streamId ?? '';
      if (_curatedIds.contains(id)) continue;

      double score = ContentIntelligenceService.scoreLive(l, profile, categoryIdToName);
      final reasons = ["Recommended for You"];

      // Learning loop boosts
      if (profile.categoryClicks.containsKey(l.categoryId)) {
        final clicks = profile.categoryClicks[l.categoryId] ?? 0;
        score += min(clicks * 5.0, 50.0);
        reasons.add("High interest category (learned preference)");
      }
      if (profile.favorites.contains(id)) {
        score += 120;
        reasons.add("Saved in favorites list");
      }
      if (profile.recentWatchHistory.contains(id)) {
        score += 40;
        reasons.add("Frequently watched feed");
      }

      candidates.add(RankedItem<ChannelLive>(
        item: l,
        score: score,
        confidence: 0.92,
        reasons: reasons,
        contentType: 'live',
        sourceRow: 'concierge_picks',
      ));
    }

    // Add Movie VOD candidates
    for (final m in allMovies) {
      final id = m.streamId ?? '';
      if (_curatedIds.contains(id)) continue;
      final catName = categoryIdToName[m.categoryId] ?? '';
      if (!ContentIntelligenceService.isMovieVOD(m, categoryName: catName)) continue;

      double score = ContentIntelligenceService.scoreMovie(m, profile, categoryIdToName);
      final reasons = ["VOD movie personalized pick"];

      if (profile.categoryClicks.containsKey(m.categoryId)) {
        final clicks = profile.categoryClicks[m.categoryId] ?? 0;
        score += min(clicks * 5.0, 50.0);
        reasons.add("Natively preferred movie category");
      }
      if (profile.favorites.contains(id)) {
        score += 120;
        reasons.add("Favorited movie title");
      }

      candidates.add(RankedItem<ChannelMovie>(
        item: m,
        score: score,
        confidence: 0.88,
        reasons: reasons,
        contentType: 'movie',
        sourceRow: 'concierge_picks',
      ));
    }

    // Sort concierge picks
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final List<RankedItem<dynamic>> results = [];
    for (final r in candidates.take(12)) {
      results.add(r);
      _curatedIds.add(r.item.streamId ?? '');
      _logQAExplanation(r);
    }
    return results;
  }
}

class CurationParams {
  final List<ChannelLive> lives;
  final List<ChannelMovie> movies;
  final List<ChannelSerie> series;
  final UserPreferenceProfile profile;
  final List<CategoryModel> categories;

  CurationParams({
    required this.lives,
    required this.movies,
    required this.series,
    required this.profile,
    required this.categories,
  });
}

class CurationResult {
  final List<RankedItem<ChannelMovie>> heroRanked;
  final List<ChannelMovie> trendingMovies;
  final List<ChannelSerie> featuredSeries;
  final List<ChannelLive> sports;
  final List<ChannelLive> news;
  final List<RankedItem<dynamic>> concierge;
  final List<PremiumPlusItem> premiumPlusItems;

  CurationResult({
    required this.heroRanked,
    required this.trendingMovies,
    required this.featuredSeries,
    required this.sports,
    required this.news,
    required this.concierge,
    required this.premiumPlusItems,
  });
}

CurationResult performBackgroundCuration(CurationParams params) {
  final curator = RowCurationService();
  final Map<String, String> categoryIdToName = {
    for (final cat in params.categories)
      if (cat.categoryId != null && cat.categoryName != null)
        cat.categoryId!: cat.categoryName!
  };

  final heroRanked = curator.buildHeroItems(
    params.movies,
    params.series,
    params.lives,
    params.profile,
    categoryIdToName,
  );
  final trendingMovies = curator.buildTrendingMovies(params.movies, params.profile, categoryIdToName);
  final featuredSeries = curator.buildFeaturedSeries(params.series, params.profile, categoryIdToName);
  final sports = curator.buildUsaSports(params.lives, params.profile, categoryIdToName);
  final news = curator.buildLocalNews(params.lives, params.profile, categoryIdToName);
  final concierge = curator.buildConciergePicks(
    params.lives,
    params.movies,
    params.series,
    params.profile,
    categoryIdToName,
  );

  final premiumPlusItems = PremiumPlusService.matchPremiumPlusChannels(
    params.lives,
    categoryIdToName: categoryIdToName,
    forceRefresh: true,
  );

  return CurationResult(
    heroRanked: heroRanked,
    trendingMovies: trendingMovies,
    featuredSeries: featuredSeries,
    sports: sports,
    news: news,
    concierge: concierge,
    premiumPlusItems: premiumPlusItems,
  );
}
