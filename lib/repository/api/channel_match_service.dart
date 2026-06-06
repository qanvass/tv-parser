import '../models/channel_live.dart';
import '../models/spotlight_event.dart';
import '../models/user_preference_profile.dart';
import 'local_market_service.dart';

class ChannelMatchResult {
  final ChannelLive? bestChannel;
  final List<ChannelLive> alternativeChannels;
  final double confidenceScore;
  final List<String> matchReasons;

  const ChannelMatchResult({
    this.bestChannel,
    this.alternativeChannels = const [],
    this.confidenceScore = 0.0,
    this.matchReasons = const [],
  });
}

class ChannelMatchService {
  /// Matches a SpotlightEvent against the full playlist of live channels
  static ChannelMatchResult matchEvent({
    required SpotlightEvent event,
    required List<ChannelLive> allLiveChannels,
  }) {
    if (allLiveChannels.isEmpty) {
      return const ChannelMatchResult();
    }

    final List<MapEntry<ChannelLive, double>> scoredChannels = [];
    final List<String> reasons = [];

    for (final channel in allLiveChannels) {
      final name = (channel.name ?? '').toLowerCase();
      final catId = (channel.categoryId ?? '').toLowerCase();
      double score = 0.0;

      // 1. Direct Network Matches
      for (final network in event.networks) {
        final netLower = network.toLowerCase();
        
        // Exact name match or contains surrounded by word bounds
        if (name == netLower) {
          score += 150.0;
        } else if (name.startsWith('$netLower ') || name.endsWith(' $netLower') || name.contains(' $netLower ')) {
          score += 130.0;
        } else if (name.contains(netLower)) {
          score += 100.0;
        }

        // Special Affiliate mapping (e.g. ABC -> WABC, KABC)
        if (netLower == 'abc') {
          if (name.contains('wabc') || name.contains('kabc') || name.contains('local abc')) {
            score += 120.0;
          }
        } else if (netLower == 'nbc') {
          if (name.contains('wnbc') || name.contains('knbc') || name.contains('local nbc')) {
            score += 120.0;
          }
        } else if (netLower == 'cbs') {
          if (name.contains('wcbs') || name.contains('kcbs') || name.contains('local cbs')) {
            score += 120.0;
          }
        } else if (netLower == 'fox') {
          if (name.contains('wfox') || name.contains('kfox') || name.contains('local fox')) {
            score += 120.0;
          }
        }
      }

      // Local Market Call Sign & City Match Boosts
      final activeMarket = LocalMarketService.getActiveMarket();
      final prefProfile = UserPreferenceProfile.load();
      if (prefProfile.locationFeatureEnabled && activeMarket != null) {
        final cityLower = activeMarket.city.toLowerCase();
        for (final network in event.networks) {
          final netLower = network.toLowerCase();
          
          // Network + City match gets strong boost
          if (name.contains(netLower) && name.contains(cityLower)) {
            score += 150.0;
          }

          // Callsign exact or containing alias matches get strongest boost
          final aliases = activeMarket.stationAliases[network] ?? [];
          for (final alias in aliases) {
            final alLower = alias.toLowerCase();
            if (name == alLower) {
              score += 200.0; // Callsign exact match gets strongest boost
            } else if (name.startsWith('$alLower ') || name.endsWith(' $alLower') || name.contains(' $alLower ')) {
              score += 150.0; // Callsign word match gets strong boost
            } else if (name.contains(alLower)) {
              score += 100.0;
            }
          }
        }
      }

      // 2. Keyword Matches
      for (final keyword in event.keywords) {
        final kwLower = keyword.toLowerCase();
        if (name.contains(kwLower)) {
          score += 40.0;
        }
      }

      // 3. Category & Quality Boosts
      if (score > 0) {
        // Boost if matches sports keywords or sports category
        final isSportsEvent = event.sport.toLowerCase() != 'news';
        if (isSportsEvent && (catId.contains('sport') || name.contains('sport') || name.contains('espn') || name.contains('nba') || name.contains('nfl'))) {
          score += 30.0;
        } else if (!isSportsEvent && (catId.contains('news') || name.contains('news') || name.contains('cnn') || name.contains('msnbc'))) {
          score += 30.0;
        }

        // Boost high definition
        if (name.contains('hd') || name.contains('fhd') || name.contains('1080p') || name.contains('1080')) {
          score += 10.0;
        }
        if (name.contains('4k') || name.contains('uhd')) {
          score += 15.0;
        }
      }

      if (score > 0) {
        scoredChannels.add(MapEntry(channel, score));
      }
    }

    // If no match found, check for broad keyword matches across all streams
    if (scoredChannels.isEmpty) {
      for (final channel in allLiveChannels) {
        final name = (channel.name ?? '').toLowerCase();
        double score = 0.0;
        for (final keyword in event.keywords) {
          if (name.contains(keyword.toLowerCase())) {
            score += 20.0;
          }
        }
        if (score > 0) {
          scoredChannels.add(MapEntry(channel, score));
        }
      }
    }

    if (scoredChannels.isEmpty) {
      return const ChannelMatchResult();
    }

    // Sort by score desc
    scoredChannels.sort((a, b) => b.value.compareTo(a.value));

    final bestCh = scoredChannels.first.key;
    final double maxScore = scoredChannels.first.value;

    // Resolve reason text
    reasons.add("Highest matching score of ${maxScore.toInt()} on channel '${bestCh.name}'");
    if (bestCh.name!.toLowerCase().contains('hd') || bestCh.name!.toLowerCase().contains('fhd')) {
      reasons.add("High-definition stream selected");
    }

    final alternatives = scoredChannels
        .skip(1)
        .take(5)
        .map((e) => e.key)
        .toList();

    // Map score to confidence percentage (0.0 to 1.0)
    double confidence = (maxScore / 250.0).clamp(0.1, 1.0);

    return ChannelMatchResult(
      bestChannel: bestCh,
      alternativeChannels: alternatives,
      confidenceScore: confidence,
      matchReasons: reasons,
    );
  }
}
