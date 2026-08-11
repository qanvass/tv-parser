import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/starlite_vod_m3u_urls.dart';
import '../models/epg.dart';
import '../provider/epg_channel_matcher.dart';
import '../provider/provider_capability_store.dart';
import '../provider/title_normalizer.dart';
import 'xmltv_models.dart';
import 'xmltv_parser.dart';

/// Downloads / caches XMLTV and answers now/next. Never blocks splash.
///
/// Disable with `--dart-define=ENABLE_XMLTV_EPG=false`.
class XmlTvRepository extends ChangeNotifier {
  XmlTvRepository._();
  static final XmlTvRepository instance = XmlTvRepository._();

  static const bool isFeatureEnabled = bool.fromEnvironment(
    'ENABLE_XMLTV_EPG',
    defaultValue: true,
  );

  static const Duration cacheTtl = Duration(hours: 6);
  static const Duration lookback = Duration(hours: 2);
  static const Duration lookahead = Duration(hours: 14);

  final EpgChannelMatcher matcher = EpgChannelMatcher();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/gzip, application/xml, text/xml, */*',
      },
    ),
  );

  Map<String, XmlTvChannel> _channels = {};
  Map<String, List<XmlTvProgramme>> _programmes = {};
  String? _loadedUrl;
  DateTime? _fetchedAt;
  bool _loading = false;
  bool _ready = false;
  String? _lastError;

  bool get isReady => _ready;
  bool get isLoading => _loading;
  String? get loadedUrl => _loadedUrl;
  String? get lastError => _lastError;
  int get channelCount => _channels.length;
  int get programmeCount =>
      _programmes.values.fold<int>(0, (n, list) => n + list.length);

  Iterable<String> get epgChannelIds => _channels.keys;

  /// Resolve URL from capabilities, then known Live-family default.
  String? resolveUrl({String? playlistUrl}) {
    final caps = ProviderCapabilityStore.instance.cached;
    final fromCaps = caps?.xmlTvUrl?.trim();
    if (fromCaps != null && fromCaps.isNotEmpty) return fromCaps;
    if (playlistUrl != null && playlistUrl.isNotEmpty) {
      return StarliteVodM3uUrls.defaultXmlTvUrl(playlistUrl);
    }
    return null;
  }

  /// Fire-and-forget load. Safe to call many times.
  Future<void> ensureLoaded({String? playlistUrl, bool force = false}) async {
    if (!isFeatureEnabled) return;
    if (_loading) return;
    if (_ready && !force && _fetchedAt != null) {
      if (DateTime.now().toUtc().difference(_fetchedAt!) < cacheTtl) {
        return;
      }
    }

    final url = resolveUrl(playlistUrl: playlistUrl);
    if (url == null || url.isEmpty) {
      debugPrint('[XMLTV] no url — skip');
      return;
    }

    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (!force) {
        final cached = await _readDiskCache(url);
        if (cached != null) {
          _apply(cached, url);
          debugPrint(
            '[XMLTV] cache hit channels=${_channels.length} '
            'programmes=$programmeCount',
          );
          return;
        }
      }

      debugPrint('[XMLTV] download start');
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('empty xmltv body');
      }

      final now = DateTime.now().toUtc();
      final payload = await compute(_parseGzipIsolate, <String, dynamic>{
        'bytes': Uint8List.fromList(bytes),
        'startMs': now.subtract(lookback).millisecondsSinceEpoch,
        'endMs': now.add(lookahead).millisecondsSinceEpoch,
      });

      final result = _resultFromIsolate(payload);
      _apply(result, url);
      await _writeDiskCache(url, result);
      debugPrint(
        '[XMLTV] loaded channels=${_channels.length} '
        'programmes=$programmeCount url-host=${Uri.tryParse(url)?.host}',
      );
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[XMLTV] load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  XmlTvNowNext? nowNext({
    String? tvgId,
    String? channelId,
    String? callsign,
    String? channelName,
    String? country,
    String? streamId,
    DateTime? at,
  }) {
    if (!_ready || _programmes.isEmpty) return null;

    final inferredCountry = country ?? countryFromTvgId(tvgId);
    final rawMatch = matcher.match(
      epgChannelIds: _matchCorpus(),
      tvgId: tvgId,
      channelId: channelId ?? streamId,
      callsign: callsign ?? _callsignFromTvgId(tvgId),
      channelName: channelName,
      country: inferredCountry,
      manualKey: streamId ?? tvgId,
    );
    final matched = _canonicalChannelId(rawMatch);
    if (matched == null || matched.isEmpty) return null;

    final list = _programmes[matched];
    if (list == null || list.isEmpty) return null;

    final t = (at ?? DateTime.now()).toUtc();
    XmlTvProgramme? now;
    for (final p in list) {
      if (p.contains(t)) {
        now = p;
        break;
      }
    }
    // No current programme — do not invent a "now" from upcoming.
    if (now == null) return null;

    XmlTvProgramme? next;
    for (final p in list) {
      if (p.start.isAfter(now.start) && !p.start.isBefore(now.stop)) {
        next = p;
        break;
      }
    }

    final exact = tvgId != null &&
        (tvgId == matched ||
            TitleNormalizer.normalizeChannelId(tvgId) ==
                TitleNormalizer.normalizeChannelId(matched));
    return XmlTvNowNext(
      epgChannelId: matched,
      now: now,
      next: next,
      matchConfidence: exact ? 1.0 : 0.7,
    );
  }

  List<EpgModel> nowNextAsEpgModels({
    String? tvgId,
    String? channelId,
    String? callsign,
    String? channelName,
    String? country,
    String? streamId,
  }) {
    final pair = nowNext(
      tvgId: tvgId,
      channelId: channelId,
      callsign: callsign,
      channelName: channelName,
      country: country,
      streamId: streamId,
    );
    if (pair == null) return const [];
    return [
      _toEpg(pair.now),
      if (pair.next != null) _toEpg(pair.next!),
    ];
  }

  Future<void> clear() async {
    _channels = {};
    _programmes = {};
    _loadedUrl = null;
    _fetchedAt = null;
    _ready = false;
    _lastError = null;
    try {
      final dir = await _dir();
      for (final name in ['xmltv.xml.gz', 'xmltv_index.json', 'xmltv_meta.json']) {
        final f = File('${dir.path}/$name');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  /// `cnn.us` → `us` when the suffix looks like a country/region code.
  static String? countryFromTvgId(String? tvgId) {
    if (tvgId == null || !tvgId.contains('.')) return null;
    final last = tvgId.split('.').last.trim().toLowerCase();
    if (last.length == 2 && RegExp(r'^[a-z]{2}$').hasMatch(last)) return last;
    return null;
  }

  static String? _callsignFromTvgId(String? tvgId) {
    if (tvgId == null || tvgId.isEmpty) return null;
    final head = tvgId.split('.').first.trim();
    return head.isEmpty ? null : head;
  }

  Iterable<String> _matchCorpus() sync* {
    yield* _channels.keys;
    for (final ch in _channels.values) {
      final name = ch.displayName;
      if (name != null && name.isNotEmpty) yield name;
    }
  }

  String? _canonicalChannelId(String? key) {
    if (key == null || key.isEmpty) return null;
    if (_channels.containsKey(key) || _programmes.containsKey(key)) {
      return key;
    }
    final norm = TitleNormalizer.normalizeChannelId(key);
    for (final ch in _channels.values) {
      if (TitleNormalizer.normalizeChannelId(ch.id) == norm) return ch.id;
      final name = ch.displayName;
      if (name != null &&
          TitleNormalizer.normalizeChannelId(name) == norm) {
        return ch.id;
      }
    }
    return null;
  }

  void _apply(XmlTvParseResult result, String url) {
    _channels = result.channels;
    _programmes = result.programmes;
    _loadedUrl = url;
    _fetchedAt = DateTime.now().toUtc();
    _ready = result.channelCount > 0;
  }

  EpgModel _toEpg(XmlTvProgramme p) {
    return EpgModel(
      title: p.title,
      description: p.description,
      channelId: p.channelId,
      start: p.start.toIso8601String(),
      end: p.stop.toIso8601String(),
      startTimestamp: (p.start.millisecondsSinceEpoch ~/ 1000).toString(),
      stopTimestamp: (p.stop.millisecondsSinceEpoch ~/ 1000).toString(),
    );
  }

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/m3u_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<XmlTvParseResult?> _readDiskCache(String url) async {
    try {
      final dir = await _dir();
      final metaFile = File('${dir.path}/xmltv_meta.json');
      final indexFile = File('${dir.path}/xmltv_index.json');
      if (!await metaFile.exists() || !await indexFile.exists()) return null;
      final meta = jsonDecode(await metaFile.readAsString());
      if (meta is! Map) return null;
      if (meta['url'] != url) return null;
      final fetched = DateTime.tryParse(meta['fetched_at'] as String? ?? '');
      if (fetched == null) return null;
      if (DateTime.now().toUtc().difference(fetched.toUtc()) > cacheTtl) {
        return null;
      }
      final raw = jsonDecode(await indexFile.readAsString());
      if (raw is! Map) return null;
      return _resultFromCacheJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('[XMLTV] cache read error: $e');
      return null;
    }
  }

  Future<void> _writeDiskCache(String url, XmlTvParseResult result) async {
    try {
      final dir = await _dir();
      final index = <String, dynamic>{
        'channels': {
          for (final e in result.channels.entries)
            e.key: {
              'id': e.value.id,
              if (e.value.displayName != null) 'n': e.value.displayName,
              if (e.value.iconUrl != null) 'i': e.value.iconUrl,
            },
        },
        'programmes': {
          for (final e in result.programmes.entries)
            e.key: e.value.map((p) => p.toJson()).toList(),
        },
      };
      await File('${dir.path}/xmltv_index.json').writeAsString(
        jsonEncode(index),
        flush: true,
      );
      await File('${dir.path}/xmltv_meta.json').writeAsString(
        jsonEncode({
          'url': url,
          'fetched_at': DateTime.now().toUtc().toIso8601String(),
          'channels': result.channelCount,
          'programmes': result.programmeCount,
        }),
        flush: true,
      );
    } catch (e) {
      debugPrint('[XMLTV] cache write error: $e');
    }
  }

  XmlTvParseResult _resultFromCacheJson(Map<String, dynamic> raw) {
    final channels = <String, XmlTvChannel>{};
    final chRaw = raw['channels'];
    if (chRaw is Map) {
      for (final e in chRaw.entries) {
        final v = e.value;
        if (v is! Map) continue;
        final id = '${e.key}';
        channels[id] = XmlTvChannel(
          id: v['id'] as String? ?? id,
          displayName: v['n'] as String?,
          iconUrl: v['i'] as String?,
        );
      }
    }
    final programmes = <String, List<XmlTvProgramme>>{};
    final pRaw = raw['programmes'];
    if (pRaw is Map) {
      for (final e in pRaw.entries) {
        final list = e.value;
        if (list is! List) continue;
        programmes['${e.key}'] = list
            .whereType<Map>()
            .map((m) => XmlTvProgramme.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    }
    return XmlTvParseResult(channels: channels, programmes: programmes);
  }

  XmlTvParseResult _resultFromIsolate(Map<String, dynamic> payload) {
    final channels = <String, XmlTvChannel>{};
    final chRaw = payload['channels'];
    if (chRaw is Map) {
      for (final e in chRaw.entries) {
        final v = e.value;
        if (v is! Map) continue;
        channels['${e.key}'] = XmlTvChannel(
          id: v['id'] as String? ?? '${e.key}',
          displayName: v['n'] as String?,
          iconUrl: v['i'] as String?,
        );
      }
    }
    final programmes = <String, List<XmlTvProgramme>>{};
    final pRaw = payload['programmes'];
    if (pRaw is Map) {
      for (final e in pRaw.entries) {
        final list = e.value;
        if (list is! List) continue;
        programmes['${e.key}'] = list
            .whereType<Map>()
            .map((m) => XmlTvProgramme.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    }
    return XmlTvParseResult(channels: channels, programmes: programmes);
  }
}

Map<String, dynamic> _parseGzipIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final start = DateTime.fromMillisecondsSinceEpoch(
    args['startMs'] as int,
    isUtc: true,
  );
  final end = DateTime.fromMillisecondsSinceEpoch(
    args['endMs'] as int,
    isUtc: true,
  );
  final parsed = XmlTvParser.parseGzipBytes(
    bytes,
    windowStart: start,
    windowEnd: end,
  );
  return {
    'channels': {
      for (final e in parsed.channels.entries)
        e.key: {
          'id': e.value.id,
          if (e.value.displayName != null) 'n': e.value.displayName,
          if (e.value.iconUrl != null) 'i': e.value.iconUrl,
        },
    },
    'programmes': {
      for (final e in parsed.programmes.entries)
        e.key: e.value.map((p) => p.toJson()).toList(),
    },
  };
}
