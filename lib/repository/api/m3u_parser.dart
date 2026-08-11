import 'dart:convert';

import '../models/category.dart';
import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import '../provider/tmdb_match.dart';
import 'artwork_url_resolver.dart';

/// Content type for one M3U `#EXTINF` + URL pair.
enum M3uEntryType { live, movie, series }

/// Full classified M3U catalog — no silent truncation.
class M3uParseResult {
  final List<CategoryModel> liveCategories;
  final List<CategoryModel> movieCategories;
  final List<CategoryModel> seriesCategories;
  final List<ChannelLive> liveChannels;
  final List<ChannelMovie> movieChannels;
  final List<ChannelSerie> seriesChannels;

  /// Raw `#EXTINF`+URL pairs successfully turned into catalog rows.
  final int parsedEntries;

  /// EXTINF lines seen (including pairs that lacked a URL).
  final int extinfSeen;

  const M3uParseResult({
    required this.liveCategories,
    required this.movieCategories,
    required this.seriesCategories,
    required this.liveChannels,
    required this.movieChannels,
    required this.seriesChannels,
    required this.parsedEntries,
    required this.extinfSeen,
  });

  Map<String, int> get byType => {
        'live': liveChannels.length,
        'movie': movieChannels.length,
        'series': seriesChannels.length,
      };

  /// Legacy shape used by older call sites.
  Map<String, dynamic> toLegacyMap() => {
        'categories': liveCategories,
        'channels': liveChannels,
      };
}

class M3uParser {
  /// Parse playlist text into a typed catalog (live / movie / series).
  /// Every valid EXTINF+URL pair is kept — nothing is top-N capped.
  ///
  /// When [forceEntryType] is set (e.g. known `/m3u8/movies` or `/m3u8/tvshows`
  /// playlists), every row is stored as that type — needed because Starlite
  /// VOD stream URLs often look like `/api/stream/` and would otherwise classify
  /// as live.
  static M3uParseResult parseCatalog(
    String content, {
    M3uEntryType? forceEntryType,
  }) {
    final liveCategories = <CategoryModel>[];
    final movieCategories = <CategoryModel>[];
    final seriesCategories = <CategoryModel>[];
    final liveChannels = <ChannelLive>[];
    final movieChannels = <ChannelMovie>[];
    final seriesChannels = <ChannelSerie>[];

    final liveCatIds = <String, String>{};
    final movieCatIds = <String, String>{};
    final seriesCatIds = <String, String>{};

    int channelIdCounter = 1;
    int extinfSeen = 0;

    final lines = const LineSplitter().convert(content);
    String? currentExtInf;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
        extinfSeen++;
      } else if (!line.startsWith('#')) {
        if (currentExtInf == null) continue;

        final streamUrl = line;
        final name = _extractName(currentExtInf, channelIdCounter);
        final rawLogo = _parseAttribute(currentExtInf, 'tvg-logo');
        final tvgId = _parseAttribute(currentExtInf, 'tvg-id') ?? '';

        var groupTitle =
            _parseAttribute(currentExtInf, 'group-title') ?? 'Uncategorized';
        if (groupTitle.trim().isEmpty) groupTitle = 'Uncategorized';

        final tvgType = _parseAttribute(currentExtInf, 'tvg-type') ?? '';
        final entryType = forceEntryType ??
            classifyEntry(
              url: streamUrl,
              groupTitle: groupTitle,
              name: name,
              tvgType: tvgType,
            );
        final streamId = 'm3u_stream_$channelIdCounter';

        // Starlite CDN invent only for live — VOD posters come from tvg-logo /
        // XC detail fields, not media.starlite.best/{id}.png guesses.
        final logo = entryType == M3uEntryType.live
            ? (ArtworkUrlResolver.resolveLiveLogo(
                  primaryUrl: rawLogo,
                  epgOrTvgId: tvgId,
                ) ??
                '')
            : (ArtworkUrlResolver.resolveVodPoster(streamIcon: rawLogo) ?? '');

        switch (entryType) {
          case M3uEntryType.live:
            final catId = _ensureCategory(
              groupTitle: groupTitle,
              nameToId: liveCatIds,
              categories: liveCategories,
              idPrefix: 'm3u_cat_',
            );
            liveChannels.add(
              ChannelLive(
                num: channelIdCounter.toString(),
                name: name,
                streamType: 'live',
                streamId: streamId,
                streamIcon: logo.isEmpty ? null : logo,
                categoryId: catId,
                directSource: streamUrl,
                epgChannelId: tvgId.isEmpty ? null : tvgId,
              ),
            );
            break;
          case M3uEntryType.movie:
            final catId = _ensureCategory(
              groupTitle: groupTitle,
              nameToId: movieCatIds,
              categories: movieCategories,
              idPrefix: 'm3u_movie_cat_',
            );
            final tvgName = _parseAttribute(currentExtInf, 'tvg-name');
            movieChannels.add(
              ChannelMovie(
                num: channelIdCounter.toString(),
                name: name,
                streamType: 'movie',
                streamId: streamId,
                streamIcon: logo.isEmpty ? null : logo,
                categoryId: catId,
                containerExtension: _containerExtension(streamUrl),
                directSource: streamUrl,
                imdbId: TmdbMatch.normalizeImdbId(tvgId) ??
                    TmdbMatch.normalizeImdbId(tvgName),
              ),
            );
            break;
          case M3uEntryType.series:
            final catId = _ensureCategory(
              groupTitle: groupTitle,
              nameToId: seriesCatIds,
              categories: seriesCategories,
              idPrefix: 'm3u_series_cat_',
            );
            seriesChannels.add(
              ChannelSerie(
                num: channelIdCounter.toString(),
                name: name,
                seriesId: streamId,
                cover: logo.isEmpty ? null : logo,
                categoryId: catId,
                directSource: streamUrl,
              ),
            );
            break;
        }

        channelIdCounter++;
        currentExtInf = null;
      }
    }

    return M3uParseResult(
      liveCategories: liveCategories,
      movieCategories: movieCategories,
      seriesCategories: seriesCategories,
      liveChannels: liveChannels,
      movieChannels: movieChannels,
      seriesChannels: seriesChannels,
      parsedEntries: liveChannels.length +
          movieChannels.length +
          seriesChannels.length,
      extinfSeen: extinfSeen,
    );
  }

  /// Backward-compatible parse used by older callers (live-only view).
  static Map<String, dynamic> parse(String content) {
    return parseCatalog(content).toLegacyMap();
  }

  /// Classify one playlist entry.
  /// Priority: URL path → `tvg-type` → strong group-title → extension hints.
  /// Conservative on group keywords so Apollo live packs (Entertainment,
  /// Cinemax-as-live, etc.) are not mis-routed into Movies/Series.
  static M3uEntryType classifyEntry({
    required String url,
    required String groupTitle,
    required String name,
    String tvgType = '',
  }) {
    final u = url.toLowerCase();
    final g = groupTitle.toLowerCase();
    final t = tvgType.toLowerCase().trim();

    // Apollo/Starlite live CDN — always live regardless of group name.
    if (u.contains('livetv') || u.contains('livetv.epg')) {
      return M3uEntryType.live;
    }

    // Classic Xtream-shaped paths embedded in M3U
    if (u.contains('/series/') ||
        u.contains('series.epg') ||
        u.contains('/episode/')) {
      return M3uEntryType.series;
    }
    if (u.contains('/movie/') ||
        u.contains('/movies/') ||
        u.contains('/vod/') ||
        u.contains('movie.epg') ||
        u.contains('vod.epg')) {
      return M3uEntryType.movie;
    }
    if (u.contains('/live/')) {
      return M3uEntryType.live;
    }

    // Explicit EXTINF type (Xtream / mixed playlists)
    if (t == 'movie' || t == 'movies' || t == 'vod') {
      return M3uEntryType.movie;
    }
    if (t == 'series' || t == 'serie' || t == 'tvshow' || t == 'show') {
      return M3uEntryType.series;
    }
    if (t == 'live') {
      return M3uEntryType.live;
    }

    // Generic /api/stream/ without livetv → still live for Starlite family
    if (u.contains('/api/stream/')) {
      return M3uEntryType.live;
    }

    // Strong group-title signals only (avoid Entertainment / sports packs)
    if (_looksSeriesGroup(g)) return M3uEntryType.series;
    if (_looksMovieGroup(g)) return M3uEntryType.movie;

    // File extension hints when path is opaque
    if (u.endsWith('.mp4') ||
        u.endsWith('.mkv') ||
        u.endsWith('.avi') ||
        u.contains('.mp4?')) {
      if (_looksSeriesGroup(g) ||
          RegExp(r'\bs0?\d+e0?\d+\b', caseSensitive: false).hasMatch(name)) {
        return M3uEntryType.series;
      }
      return M3uEntryType.movie;
    }

    return M3uEntryType.live;
  }

  static bool _looksMovieGroup(String g) {
    if (RegExp(r'\b(live|news|sport|sports|tv)\b').hasMatch(g)) return false;
    return RegExp(
      r'\b(vod|movies?|films?|cinema|on[\s-]?demand)\b',
    ).hasMatch(g);
  }

  static bool _looksSeriesGroup(String g) {
    if (RegExp(r'\b(live|news|sport|sports)\b').hasMatch(g)) return false;
    return RegExp(r'\b(series|seasons?|tv[\s-]?shows?|episodes?)\b')
        .hasMatch(g);
  }

  static String _extractName(String extInf, int fallbackId) {
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex != -1 && commaIndex < extInf.length - 1) {
      final name = extInf.substring(commaIndex + 1).trim();
      if (name.isNotEmpty) return name;
    }
    return _parseAttribute(extInf, 'tvg-name') ?? 'Channel $fallbackId';
  }

  static String _ensureCategory({
    required String groupTitle,
    required Map<String, String> nameToId,
    required List<CategoryModel> categories,
    required String idPrefix,
  }) {
    final existing = nameToId[groupTitle];
    if (existing != null) return existing;
    final catId = '$idPrefix${categories.length + 1}';
    nameToId[groupTitle] = catId;
    categories.add(
      CategoryModel(
        categoryId: catId,
        categoryName: groupTitle,
        parentId: '0',
      ),
    );
    return catId;
  }

  static String? _containerExtension(String url) {
    final lower = url.toLowerCase();
    for (final ext in ['mp4', 'mkv', 'avi', 'ts', 'm3u8']) {
      if (lower.contains('.$ext')) return ext;
    }
    return 'mp4';
  }

  static String? _parseAttribute(String line, String attributeName) {
    final regExp = RegExp('$attributeName="([^"]*)"', caseSensitive: false);
    final match = regExp.firstMatch(line);
    if (match != null) return match.group(1);

    final regExpNoQuotes =
        RegExp('$attributeName=([^\\s,]+)', caseSensitive: false);
    final matchNoQuotes = regExpNoQuotes.firstMatch(line);
    if (matchNoQuotes != null) return matchNoQuotes.group(1);

    return null;
  }
}
