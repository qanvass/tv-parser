import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/starlite_vod_m3u_urls.dart';
import 'm3u_header_inspector.dart';
import 'provider_capabilities.dart';
import 'provider_capability_store.dart';
import 'provider_enums.dart';
import 'xtream_probe_url_builder.dart';

/// Probes a provider after login / M3U commit to learn real capabilities.
///
/// Plain M3U is the minimum tier until probes complete. Never logs passwords.
class ProviderCapabilityInspector {
  ProviderCapabilityInspector._({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                validateStatus: (s) => s != null && s < 500,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 12; Android TV) AppleWebKit/537.36',
                  'Accept': 'application/json, text/plain, */*',
                },
              ),
            );

  static final ProviderCapabilityInspector instance =
      ProviderCapabilityInspector._();

  final Dio _dio;
  ProviderCapabilities? lastCapabilities;

  /// After M3U catalog commit — non-blocking from caller's perspective.
  Future<ProviderCapabilities> inspectAfterM3u({
    required String playlistUrl,
    required String m3uContent,
    String? username,
    String? password,
  }) async {
    final notes = <String>[];
    var xmlTv = M3uHeaderInspector.extractXmlTvUrl(m3uContent);
    xmlTv ??= StarliteVodM3uUrls.defaultXmlTvUrl(playlistUrl);
    var caps = ProviderCapabilities.m3uMinimum(
      hasLive: m3uContent.contains('#EXTINF'),
      xmlTvUrl: xmlTv,
      notes: [
        'm3u_playlist',
        if (M3uHeaderInspector.extractXmlTvUrl(m3uContent) != null)
          'xmltv_header',
        if (xmlTv != null &&
            M3uHeaderInspector.extractXmlTvUrl(m3uContent) == null)
          'xmltv_default_host',
      ],
    );

    final fromPath = XtreamProbeUrlBuilder.credentialsFromListPath(playlistUrl);
    final user = (username != null && username.isNotEmpty)
        ? username
        : fromPath?.$1;
    final pass = (password != null && password.isNotEmpty)
        ? password
        : fromPath?.$2;

    final hostGuess =
        XtreamProbeUrlBuilder.hostBaseFromPlaylistUrl(playlistUrl);

    if (user != null &&
        pass != null &&
        user.isNotEmpty &&
        pass.isNotEmpty &&
        hostGuess != null) {
      notes.add('credentials_present');
      final xtream = await _probeXtream(
        hostBase: hostGuess,
        username: user,
        password: pass,
      );
      caps = _mergeM3uWithXtream(caps, xtream);
    } else {
      notes.add('no_xtream_credentials');
      caps = caps.copyWith(notes: [...caps.notes, ...notes]);
    }

    // Preserve VOD M3U sync results if that finished first (async race).
    caps = _mergePreservingVodM3u(caps, lastCapabilities);
    return _persist(caps);
  }

  /// Keep supportsVod/series/xmltv samples from a prior VOD M3U sync.
  ProviderCapabilities _mergePreservingVodM3u(
    ProviderCapabilities incoming,
    ProviderCapabilities? prior,
  ) {
    if (prior == null) return incoming;
    final priorHadVodM3u = prior.notes.any(
      (n) => n == 'starlite_vod_m3u' || n.startsWith('vod_tvshows_shards_'),
    );
    if (!priorHadVodM3u &&
        !prior.supportsVod &&
        !prior.supportsSeries &&
        prior.xmlTvUrl == null) {
      return incoming;
    }
    return incoming.copyWith(
      supportsVod: incoming.supportsVod || prior.supportsVod,
      supportsSeries: incoming.supportsSeries || prior.supportsSeries,
      supportsXmlTv: incoming.supportsXmlTv || prior.supportsXmlTv,
      xmlTvUrl: incoming.xmlTvUrl ?? prior.xmlTvUrl,
      vodStreamSample: incoming.vodStreamSample > 0
          ? incoming.vodStreamSample
          : prior.vodStreamSample,
      vodCategorySample: incoming.vodCategorySample > 0
          ? incoming.vodCategorySample
          : prior.vodCategorySample,
      seriesSample:
          incoming.seriesSample > 0 ? incoming.seriesSample : prior.seriesSample,
      seriesCategorySample: incoming.seriesCategorySample > 0
          ? incoming.seriesCategorySample
          : prior.seriesCategorySample,
      notes: [
        ...incoming.notes,
        ...prior.notes.where(
          (n) =>
              n == 'starlite_vod_m3u' ||
              n.startsWith('vod_tvshows_shards_') ||
              n.startsWith('vod_m3u_'),
        ),
      ],
    );
  }

  /// After classic Xtream `player_api` auth success.
  Future<ProviderCapabilities> inspectAfterXtream({
    required String host,
    required String username,
    required String password,
  }) async {
    final probed = await _probeXtream(
      hostBase: host,
      username: username,
      password: password,
    );
    return _persist(
      probed.copyWith(
        providerType: ProviderType.xtream,
        notes: [...probed.notes, 'xtream_login'],
      ),
    );
  }

  Future<ProviderCapabilities> _persist(ProviderCapabilities caps) async {
    lastCapabilities = caps;
    await ProviderCapabilityStore.instance.save(caps);
    debugPrint(caps.capabilityLogLine);
    if (caps.playerApiBase != null) {
      debugPrint('[CAPABILITIES] playerApiBase=${caps.playerApiBase}');
    }
    if (caps.xmlTvUrl != null) {
      debugPrint('[CAPABILITIES] xmlTvUrl=${caps.xmlTvUrl}');
    }
    if (caps.notes.isNotEmpty) {
      debugPrint('[CAPABILITIES] notes=${caps.notes.join(',')}');
    }
    return caps;
  }

  ProviderCapabilities _mergeM3uWithXtream(
    ProviderCapabilities m3u,
    ProviderCapabilities xtream,
  ) {
    final playerOk = xtream.playerApiBase != null &&
        (xtream.supportsLive ||
            xtream.supportsVod ||
            xtream.supportsSeries ||
            xtream.supportsShortEpg);
    return m3u.copyWith(
      providerType: playerOk ? ProviderType.xtream : ProviderType.m3u,
      supportsLive: m3u.supportsLive || xtream.supportsLive,
      supportsShortEpg: xtream.supportsShortEpg,
      supportsFullEpg: xtream.supportsFullEpg || m3u.supportsXmlTv,
      supportsVod: xtream.supportsVod,
      supportsSeries: xtream.supportsSeries,
      supportsCatchup: xtream.supportsCatchup,
      supportsPosters: xtream.supportsPosters || m3u.supportsPosters,
      supportsTrailers: xtream.supportsTrailers,
      playerApiBase: xtream.playerApiBase,
      notes: [...m3u.notes, ...xtream.notes],
      liveCategorySample: xtream.liveCategorySample,
      liveStreamSample: xtream.liveStreamSample,
      vodCategorySample: xtream.vodCategorySample,
      vodStreamSample: xtream.vodStreamSample,
      seriesCategorySample: xtream.seriesCategorySample,
      seriesSample: xtream.seriesSample,
      probedAt: DateTime.now().toUtc(),
    );
  }

  Future<ProviderCapabilities> _probeXtream({
    required String hostBase,
    required String username,
    required String password,
  }) async {
    final base = XtreamProbeUrlBuilder.normalizeHostBase(hostBase);
    final notes = <String>[];
    if (base.isEmpty) {
      return ProviderCapabilities(
        providerType: ProviderType.unknown,
        notes: const ['invalid_host'],
        probedAt: DateTime.now().toUtc(),
      );
    }

    var supportsLive = false;
    var supportsShortEpg = false;
    var supportsVod = false;
    var supportsSeries = false;
    var supportsPosters = false;
    var liveCats = 0;
    var liveStreams = 0;
    var vodCats = 0;
    var vodStreams = 0;
    var seriesCats = 0;
    var seriesCount = 0;
    String? playerApiBase;

    Future<dynamic> getAction(String action, [Map<String, String>? extra]) async {
      // Never log this URL — contains credentials.
      final url = XtreamProbeUrlBuilder.playerApiUrl(
        hostBase: base,
        username: username,
        password: password,
        action: action,
        extra: extra ?? const {},
      );
      try {
        final res = await _dio.get(url);
        if (res.statusCode == 404) {
          notes.add('${action}_404');
          return null;
        }
        if (res.statusCode != 200) {
          notes.add('${action}_http_${res.statusCode}');
          return null;
        }
        return res.data;
      } catch (e) {
        notes.add('${action}_error');
        debugPrint('[CAPABILITIES] probe $action failed: ${e.runtimeType}');
        return null;
      }
    }

    // Auth ping (no action) — confirms player_api exists.
    try {
      final authUrl = XtreamProbeUrlBuilder.playerApiUrl(
        hostBase: base,
        username: username,
        password: password,
      );
      final authRes = await _dio.get(authUrl);
      if (authRes.statusCode == 200 && authRes.data != null) {
        playerApiBase = base;
        notes.add('player_api_ok');
      } else if (authRes.statusCode == 404) {
        // Host has no classic XC surface (e.g. M3U-only). Not an auth failure.
        notes.add('player_api_404');
        return ProviderCapabilities(
          providerType: ProviderType.unknown,
          playerApiBase: null,
          notes: notes,
          probedAt: DateTime.now().toUtc(),
        );
      } else {
        notes.add('player_api_http_${authRes.statusCode}');
      }
    } catch (e) {
      notes.add('player_api_unreachable');
      debugPrint('[CAPABILITIES] player_api unreachable: ${e.runtimeType}');
      return ProviderCapabilities(
        providerType: ProviderType.unknown,
        notes: notes,
        probedAt: DateTime.now().toUtc(),
      );
    }

    final liveCatData = await getAction('get_live_categories');
    liveCats = _listLen(liveCatData);
    if (liveCats > 0) supportsLive = true;

    final liveStreamData = await getAction('get_live_streams');
    liveStreams = _listLen(liveStreamData);
    if (liveStreams > 0) {
      supportsLive = true;
      supportsPosters = supportsPosters || _sampleHasIcon(liveStreamData);
      final firstId = _firstStreamId(liveStreamData);
      if (firstId != null) {
        final epg = await getAction('get_short_epg', {
          'stream_id': firstId,
          'limit': '2',
        });
        if (_listLen(epg) > 0 || _mapHasEpg(epg)) {
          supportsShortEpg = true;
        }
      }
    }

    final vodCatData = await getAction('get_vod_categories');
    vodCats = _listLen(vodCatData);
    final vodData = await getAction('get_vod_streams');
    vodStreams = _listLen(vodData);
    if (vodCats > 0 || vodStreams > 0) {
      supportsVod = true;
      supportsPosters = supportsPosters || _sampleHasIcon(vodData);
    }

    final seriesCatData = await getAction('get_series_categories');
    seriesCats = _listLen(seriesCatData);
    final seriesData = await getAction('get_series');
    seriesCount = _listLen(seriesData);
    if (seriesCats > 0 || seriesCount > 0) {
      supportsSeries = true;
      supportsPosters = supportsPosters || _sampleHasIcon(seriesData);
    }

    return ProviderCapabilities(
      providerType: ProviderType.xtream,
      supportsLive: supportsLive,
      supportsShortEpg: supportsShortEpg,
      supportsFullEpg: false,
      supportsVod: supportsVod,
      supportsSeries: supportsSeries,
      supportsPosters: supportsPosters,
      supportsTrailers: false,
      playerApiBase: playerApiBase ?? (supportsLive || supportsVod || supportsSeries ? base : null),
      notes: notes,
      probedAt: DateTime.now().toUtc(),
      liveCategorySample: liveCats,
      liveStreamSample: liveStreams,
      vodCategorySample: vodCats,
      vodStreamSample: vodStreams,
      seriesCategorySample: seriesCats,
      seriesSample: seriesCount,
    );
  }

  static int _listLen(dynamic data) {
    if (data is List) return data.length;
    if (data is Map && data['epg_listings'] is List) {
      return (data['epg_listings'] as List).length;
    }
    return 0;
  }

  static bool _mapHasEpg(dynamic data) {
    if (data is Map) {
      final listings = data['epg_listings'];
      return listings is List && listings.isNotEmpty;
    }
    return false;
  }

  static String? _firstStreamId(dynamic data) {
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is Map) {
      final id = first['stream_id'] ?? first['id'];
      if (id != null) return '$id';
    }
    return null;
  }

  static bool _sampleHasIcon(dynamic data) {
    if (data is! List) return false;
    for (final row in data.take(5)) {
      if (row is! Map) continue;
      for (final key in ['stream_icon', 'cover', 'movie_image', 'icon']) {
        final v = row[key];
        if (v is String && v.startsWith('http')) return true;
      }
    }
    return false;
  }
}
