import 'title_normalizer.dart';

/// Channel ↔ EPG programme matching order (stub — no network).
///
/// Documented priority:
/// 1. Exact tvg-id
/// 2. Normalized channel ID
/// 3. Callsign
/// 4. Channel name + country
/// 5. Manual user mapping (persisted separately)
class EpgChannelMatcher {
  /// In-memory manual overrides: channelStreamId → epgChannelId.
  final Map<String, String> _manual = {};

  Map<String, String> get manualMappings => Map.unmodifiable(_manual);

  void setManualMapping(String channelKey, String epgChannelId) {
    _manual[channelKey] = epgChannelId;
  }

  void clearManualMappings() => _manual.clear();

  /// Returns the best EPG channel id key for [channel], or null if no match.
  ///
  /// [epgChannelIds] are ids present in the loaded XMLTV / provider EPG index.
  String? match({
    required Iterable<String> epgChannelIds,
    String? tvgId,
    String? channelId,
    String? callsign,
    String? channelName,
    String? country,
    String? manualKey,
  }) {
    final index = <String, String>{};
    for (final id in epgChannelIds) {
      index[id] = id;
      index[TitleNormalizer.normalizeChannelId(id)] = id;
    }

    // 5) Manual first when present (user override wins).
    if (manualKey != null && _manual.containsKey(manualKey)) {
      final mapped = _manual[manualKey]!;
      if (index.containsKey(mapped) ||
          index.containsKey(TitleNormalizer.normalizeChannelId(mapped))) {
        return index[mapped] ??
            index[TitleNormalizer.normalizeChannelId(mapped)];
      }
      // Persist stub may point at an id not yet loaded — still return it.
      return mapped;
    }

    // 1) Exact tvg-id
    if (tvgId != null && tvgId.isNotEmpty) {
      if (index.containsKey(tvgId)) return index[tvgId];
      final norm = TitleNormalizer.normalizeChannelId(tvgId);
      if (index.containsKey(norm)) return index[norm];
    }

    // 2) Normalized channel ID
    if (channelId != null && channelId.isNotEmpty) {
      final norm = TitleNormalizer.normalizeChannelId(channelId);
      if (index.containsKey(norm)) return index[norm];
      if (index.containsKey(channelId)) return index[channelId];
    }

    // 3) Callsign
    if (callsign != null && callsign.isNotEmpty) {
      final norm = TitleNormalizer.normalizeChannelId(callsign);
      if (index.containsKey(norm)) return index[norm];
      if (index.containsKey(callsign)) return index[callsign];
    }

    // 4) Channel name + country (weak)
    if (channelName != null && channelName.isNotEmpty) {
      final base = TitleNormalizer.normalizeChannelId(channelName);
      if (country != null && country.isNotEmpty) {
        final withCountry =
            TitleNormalizer.normalizeChannelId('$channelName$country');
        if (index.containsKey(withCountry)) return index[withCountry];
      }
      if (index.containsKey(base)) return index[base];
    }

    return null;
  }
}
