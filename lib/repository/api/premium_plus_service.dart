import '../models/channel_live.dart';
import '../models/premium_plus_item.dart';

class PremiumPlusService {
  static List<PremiumPlusItem>? _cachedMatches;

  // The 13 required brand catalogs with broad aliases
  static final List<PremiumPlusItem> _brandCatalog = [
    const PremiumPlusItem(
      id: "cnn",
      displayName: "CNN",
      aliases: ["cnn", "cnn usa", "cnn us", "cnn hd", "cable news network"],
      category: "NEWS",
      priority: 100,
      badgeLabel: "LIVE NEWS",
    ),
    const PremiumPlusItem(
      id: "bbc",
      displayName: "BBC",
      aliases: ["bbc", "bbc america", "bbc usa", "bbc news", "bbc world news", "bbc news hd"],
      category: "NEWS",
      priority: 95,
      badgeLabel: "WORLD NEWS",
    ),
    const PremiumPlusItem(
      id: "hbo",
      displayName: "HBO",
      aliases: ["hbo", "hbo usa", "hbo us", "hbo east", "hbo west", "hbo hd", "hbo 2", "hbo signature", "hbo family", "hbo zone", "hbo comedy"],
      category: "PREMIUM",
      priority: 90,
      badgeLabel: "PREMIUM CINEMA",
    ),
    const PremiumPlusItem(
      id: "starz",
      displayName: "Starz",
      aliases: ["starz", "starz usa", "starz us", "starz east", "starz west", "starz hd", "starz encore", "encore"],
      category: "PREMIUM",
      priority: 85,
      badgeLabel: "PREMIUM MOVIES",
    ),
    const PremiumPlusItem(
      id: "max",
      displayName: "Max",
      aliases: ["max", "hbo max", "max hd"],
      category: "PREMIUM",
      priority: 80,
      badgeLabel: "MAX ORIGINALS",
    ),
    const PremiumPlusItem(
      id: "disney",
      displayName: "Disney",
      aliases: ["disney", "disney channel", "disney usa", "disney us", "disney east", "disney west", "disney xd", "disney junior", "disney hd"],
      category: "ENTERTAINMENT",
      priority: 75,
      badgeLabel: "FAMILY & KIDS",
    ),
    const PremiumPlusItem(
      id: "paramount",
      displayName: "Paramount",
      aliases: ["paramount", "paramount network", "paramount usa", "paramount us", "paramount hd", "paramount+", "paramount plus"],
      category: "ENTERTAINMENT",
      priority: 70,
      badgeLabel: "ENTERTAINMENT",
    ),
    const PremiumPlusItem(
      id: "bet",
      displayName: "BET",
      aliases: ["bet", "bet usa", "bet us", "bet hd", "bet east", "bet west", "bet her", "bet jams", "bet soul"],
      category: "ENTERTAINMENT",
      priority: 65,
      badgeLabel: "CULTURE & SHOWS",
    ),
    const PremiumPlusItem(
      id: "bet_plus",
      displayName: "BET+",
      aliases: ["bet+", "bet plus", "bet plus usa", "bet+ usa", "bet+ us"],
      category: "ENTERTAINMENT",
      priority: 60,
      badgeLabel: "BET+ ORIGINALS",
    ),
    const PremiumPlusItem(
      id: "ppv",
      displayName: "PPV Events",
      aliases: ["ppv", "pay per view", "pay-per-view", "events ppv", "ppv events", "ufc ppv", "boxing ppv", "wwe ppv", "aew ppv", "fight ppv"],
      category: "PPV",
      priority: 55,
      badgeLabel: "PREMIUM EVENTS",
    ),
    const PremiumPlusItem(
      id: "espn",
      displayName: "ESPN",
      aliases: ["espn", "espn usa", "espn us", "espn hd", "espn east", "espn west", "espn2", "espn 2", "espnews", "espnu", "espn deportes", "sec network", "acc network"],
      category: "SPORTS",
      priority: 50,
      badgeLabel: "LIVE SPORTS",
    ),
    const PremiumPlusItem(
      id: "msnbc",
      displayName: "MSNBC",
      aliases: ["msnbc", "msnbc usa", "msnbc us", "msnbc hd", "msnbc east", "msnbc west"],
      category: "NEWS",
      priority: 45,
      badgeLabel: "NEWS & TALK",
    ),
    const PremiumPlusItem(
      id: "fox_news",
      displayName: "Fox News",
      aliases: ["fox news", "fox news channel", "fnc", "fox news usa", "fox news hd"],
      category: "NEWS",
      priority: 40,
      badgeLabel: "LIVE NEWS",
    ),
    const PremiumPlusItem(
      id: "showtime",
      displayName: "Showtime",
      aliases: ["showtime", "showtime hd", "showtime east", "showtime west", "showtime extreme", "showtime family", "showtime showcase"],
      category: "PREMIUM",
      priority: 88,
      badgeLabel: "PREMIUM MOVIES",
    ),
    const PremiumPlusItem(
      id: "cinemax",
      displayName: "Cinemax",
      aliases: ["cinemax", "cinemax hd", "cinemax east", "cinemax west", "actionmax", "moremax", "thrillermax", "moviemax"],
      category: "PREMIUM",
      priority: 82,
      badgeLabel: "PREMIUM MOVIES",
    ),
    const PremiumPlusItem(
      id: "nickelodeon",
      displayName: "Nickelodeon",
      aliases: ["nickelodeon", "nick", "nick jr", "nick toons", "nick hd", "nickelodeon hd"],
      category: "ENTERTAINMENT",
      priority: 74,
      badgeLabel: "KIDS & FAMILY",
    ),
    const PremiumPlusItem(
      id: "cartoon_network",
      displayName: "Cartoon Network",
      aliases: ["cartoon network", "cn", "adult swim", "cartoon network hd"],
      category: "ENTERTAINMENT",
      priority: 73,
      badgeLabel: "ANIMATION",
    ),
    const PremiumPlusItem(
      id: "hallmark",
      displayName: "Hallmark Channel",
      aliases: ["hallmark", "hallmark channel", "hallmark movies", "hallmark drama", "hallmark hd"],
      category: "ENTERTAINMENT",
      priority: 64,
      badgeLabel: "DRAMA & FAMILY",
    ),
    const PremiumPlusItem(
      id: "fx",
      displayName: "FX",
      aliases: ["fx", "fx hd", "fxx", "fxm", "fx movies"],
      category: "ENTERTAINMENT",
      priority: 63,
      badgeLabel: "HIT SHOWS",
    ),
    const PremiumPlusItem(
      id: "amc",
      displayName: "AMC",
      aliases: ["amc", "amc hd", "amc networks"],
      category: "ENTERTAINMENT",
      priority: 62,
      badgeLabel: "HIT MOVIES",
    ),
    const PremiumPlusItem(
      id: "discovery",
      displayName: "Discovery",
      aliases: ["discovery", "discovery channel", "discovery hd", "discovery science", "investigation discovery", "id channel", "investigation discovery hd"],
      category: "ENTERTAINMENT",
      priority: 61,
      badgeLabel: "DOCUMENTARY",
    ),
    const PremiumPlusItem(
      id: "hgtv",
      displayName: "HGTV",
      aliases: ["hgtv", "hgtv hd", "home & garden", "home and garden"],
      category: "ENTERTAINMENT",
      priority: 59,
      badgeLabel: "HOME & LIFE",
    ),
    const PremiumPlusItem(
      id: "food_network",
      displayName: "Food Network",
      aliases: ["food network", "food network hd", "cooking channel"],
      category: "ENTERTAINMENT",
      priority: 58,
      badgeLabel: "LIFESTYLE",
    ),
  ];

  static List<String> _tokenize(String name) {
    return name
        .toLowerCase()
        .replaceAll('+', ' plus')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static bool _isContiguousSublist(List<String> sub, List<String> mainList) {
    if (sub.isEmpty) return true;
    if (mainList.length < sub.length) return false;
    for (int i = 0; i <= mainList.length - sub.length; i++) {
      bool match = true;
      for (int j = 0; j < sub.length; j++) {
        if (mainList[i + j] != sub[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }


  static double _scoreMatchOptimized(
    String name,
    String epg,
    String catName,
    List<String> nameTokens,
    List<String> epgTokens,
    List<String> catTokens,
    String aliasNorm,
    List<String> aliasTokens,
    String brandId,
    ChannelLive channel,
  ) {
    if (name.isEmpty) return 0.0;

    // Check exact matches
    if (name == aliasNorm || epg == aliasNorm) {
      return 300.0; // Perfect match
    }

    bool isMatch = _isContiguousSublist(aliasTokens, nameTokens) ||
                   _isContiguousSublist(aliasTokens, epgTokens) ||
                   _isContiguousSublist(aliasTokens, catTokens);

    if (!isMatch) {
      if (aliasNorm.length > 2 && (name.contains(aliasNorm) || epg.contains(aliasNorm) || catName.contains(aliasNorm))) {
        isMatch = true;
      }
    }

    if (!isMatch) return 0.0;

    double score = 100.0;

    if (nameTokens.isNotEmpty && aliasTokens.isNotEmpty && nameTokens[0] == aliasTokens[0]) {
      score += 50.0;
    }

    if (name.contains("usa") || name.contains("us ") || name.contains(" us") || name.contains("national")) {
      score += 30.0;
    }

    if (name.contains("hd") || name.contains("fhd") || name.contains("1080p")) {
      score += 20.0;
    }

    if (brandId == "max" && name.contains("cinemax")) {
      return 0.0;
    }
    if (brandId == "bet" && name.contains("plus")) {
      score -= 80.0;
    }

    return score;
  }

  /// Processes the user's active playlist and matches high-value brand catalogs.
  /// Accepts category names to search categories/groups.
  static List<PremiumPlusItem> matchPremiumPlusChannels(List<ChannelLive> liveChannels, {Map<String, String>? categoryIdToName, bool forceRefresh = false}) {
    if (!forceRefresh && _cachedMatches != null) {
      return _cachedMatches!;
    }

    final brandAnalyses = _brandCatalog.map((brand) {
      final aliasesAnalysis = brand.aliases.map((alias) {
        final aliasNorm = _normalize(alias);
        final aliasTokens = _tokenize(aliasNorm);
        return _AliasAnalysis(aliasNorm: aliasNorm, aliasTokens: aliasTokens, original: alias);
      }).toList();
      return _BrandAnalysis(brand: brand, aliases: aliasesAnalysis);
    }).toList();

    final Map<String, ChannelLive> bestMatches = {};
    final Map<String, double> highestScores = {};

    for (final ch in liveChannels) {
      final name = _normalize(ch.name ?? '');
      final epg = _normalize(ch.epgChannelId?.toString() ?? '');
      final catName = _normalize(categoryIdToName != null ? categoryIdToName[ch.categoryId] ?? '' : '');

      if (name.isEmpty && epg.isEmpty && catName.isEmpty) continue;

      List<String>? cachedNameTokens;
      List<String>? cachedEpgTokens;
      List<String>? cachedCatTokens;

      for (final brandAnalysis in brandAnalyses) {
        final brandId = brandAnalysis.brand.id;
        double currentBest = highestScores[brandId] ?? 0.0;

        for (final aliasAnalysis in brandAnalysis.aliases) {
          final aliasNorm = aliasAnalysis.aliasNorm;

          // Fast pre-filter: skip regex tokenization and contiguous scans if the alias string doesn't even exist as a substring
          if (!name.contains(aliasNorm) && !epg.contains(aliasNorm) && !catName.contains(aliasNorm)) {
            continue;
          }

          // Lazily compute tokens only if we have a substring match candidate
          cachedNameTokens ??= _tokenize(name);
          cachedEpgTokens ??= _tokenize(epg);
          cachedCatTokens ??= _tokenize(catName);

          final score = _scoreMatchOptimized(
            name, epg, catName, cachedNameTokens, cachedEpgTokens, cachedCatTokens,
            aliasNorm, aliasAnalysis.aliasTokens, brandId, ch
          );

          if (score > 0.0 && score > currentBest) {
            currentBest = score;
            bestMatches[brandId] = ch;
            highestScores[brandId] = score;
          }
        }
      }
    }

    final List<PremiumPlusItem> results = [];
    for (final brand in _brandCatalog) {
      final bestMatch = bestMatches[brand.id];
      final score = highestScores[brand.id] ?? 0.0;
      if (bestMatch != null && score >= 100.0) {
        results.add(brand.copyWith(
          matchedChannel: bestMatch,
          confidenceScore: score,
        ));
      }
    }

    results.sort((a, b) => b.priority.compareTo(a.priority));
    _cachedMatches = results;
    return results;
  }

  /// Compatibility wrapper for tests and legacy usage
  static List<PremiumPlusItem> matchChannels(List<ChannelLive> liveChannels, {bool forceRefresh = false}) {
    return matchPremiumPlusChannels(liveChannels, forceRefresh: forceRefresh);
  }

  /// Clear cache when database or playlist is explicitly updated
  static void clearCache() {
    _cachedMatches = null;
  }
}

class _AliasAnalysis {
  final String aliasNorm;
  final List<String> aliasTokens;
  final String original;

  _AliasAnalysis({
    required this.aliasNorm,
    required this.aliasTokens,
    required this.original,
  });
}

class _BrandAnalysis {
  final PremiumPlusItem brand;
  final List<_AliasAnalysis> aliases;

  _BrandAnalysis({
    required this.brand,
    required this.aliases,
  });
}
