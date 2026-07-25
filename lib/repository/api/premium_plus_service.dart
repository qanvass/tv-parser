import '../models/channel_live.dart';
import '../models/premium_plus_item.dart';

/// Builds a small featured row using only channels supplied by the user.
///
/// No broadcaster catalog, remote logo override, or bundled channel name is
/// maintained by TV Parser. Names and artwork always come from the connected
/// playlist/provider.
class PremiumPlusService {
  static List<PremiumPlusItem>? _cachedMatches;

  static List<PremiumPlusItem> matchPremiumPlusChannels(
    List<ChannelLive> liveChannels, {
    Map<String, String>? categoryIdToName,
    bool forceRefresh = false,
  }) {
    if (!forceRefresh && _cachedMatches != null) {
      return _cachedMatches!;
    }

    final seen = <String>{};
    final results = <PremiumPlusItem>[];

    for (final channel in liveChannels) {
      final name = channel.name?.trim() ?? '';
      if (name.isEmpty || channel.isAdult == '1') continue;

      final identity = (channel.streamId?.trim().isNotEmpty ?? false)
          ? channel.streamId!.trim()
          : name.toLowerCase();
      if (!seen.add(identity)) continue;

      final category = categoryIdToName?[channel.categoryId]?.trim();
      results.add(
        PremiumPlusItem(
          id: identity,
          displayName: name,
          aliases: const [],
          category: category?.isNotEmpty == true ? category! : 'PLAYLIST',
          priority: 100 - results.length,
          badgeLabel: 'YOUR PLAYLIST',
          matchedChannel: channel,
          confidenceScore: 100,
        ),
      );

      if (results.length == 12) break;
    }

    _cachedMatches = List.unmodifiable(results);
    return _cachedMatches!;
  }

  static List<PremiumPlusItem> matchChannels(
    List<ChannelLive> liveChannels, {
    bool forceRefresh = false,
  }) {
    return matchPremiumPlusChannels(liveChannels, forceRefresh: forceRefresh);
  }

  static void clearCache() {
    _cachedMatches = null;
  }
}
