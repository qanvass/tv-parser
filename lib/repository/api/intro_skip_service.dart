import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Where an episode's opening titles start and end.
class IntroSegment {
  final Duration start;
  final Duration end;

  const IntroSegment(this.start, this.end);

  /// True while [position] is inside the intro, with enough left to be worth
  /// skipping. The button shows a moment early so it is ready when the titles
  /// begin.
  bool covers(Duration position) =>
      position >= start - const Duration(seconds: 2) &&
      position < end - const Duration(seconds: 2);
}

/// Which episode to ask about. Sent to the timestamp services; holds no
/// account or device details.
class IntroKey {
  final String imdbId;
  final int season;
  final int episode;

  const IntroKey(this.imdbId, this.season, this.episode);

  String get cacheKey => '$imdbId:$season:$episode';
}

/// Intro times for series episodes, from two public community databases.
///
/// Streams carry no chapter marks, so the times cannot be read from the video.
/// TheIntroDB is asked first, IntroDB second. An episode neither one has timed
/// returns null and the player shows no Skip Intro button: a button that
/// jumped a guessed number of seconds would not be skipping the intro.
class IntroSkipService {
  IntroSkipService._();

  static final RegExp _playlistEpisode = RegExp(
    r'/tvshow/(tt\d{5,10})/(\d{1,3})/(\d{1,4})(?:[/?#.]|$)',
  );
  static const Duration _minLength = Duration(seconds: 5);
  static const Duration _maxLength = Duration(minutes: 10);

  static final Map<String, IntroSegment?> _cache = <String, IntroSegment?>{};
  static const int _cacheCap = 200;

  /// The episode a playlist stream address names (`/tvshow/<imdb>/<s>/<e>`),
  /// or null for addresses that do not carry an IMDb id.
  static IntroKey? keyFromUrl(String url) {
    final m = _playlistEpisode.firstMatch(url);
    if (m == null) return null;
    final season = int.tryParse(m.group(2)!);
    final episode = int.tryParse(m.group(3)!);
    if (season == null || episode == null) return null;
    return IntroKey(m.group(1)!, season, episode);
  }

  /// Intro from a TheIntroDB `/v2/media` answer.
  @visibleForTesting
  static IntroSegment? parseTheIntroDb(dynamic json) {
    if (json is! Map) return null;
    final list = json['intro'];
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    if (first is! Map) return null;
    return _segment(first['start_ms'], first['end_ms']);
  }

  /// Intro from an IntroDB `/segments` answer.
  @visibleForTesting
  static IntroSegment? parseIntroDb(dynamic json) {
    if (json is! Map) return null;
    final intro = json['intro'];
    if (intro is! Map) return null;
    return _segment(intro['start_ms'], intro['end_ms']);
  }

  static IntroSegment? _segment(dynamic startMs, dynamic endMs) {
    if (endMs is! num) return null;
    final start = Duration(milliseconds: startMs is num ? startMs.round() : 0);
    final end = Duration(milliseconds: endMs.round());
    final length = end - start;
    if (start.isNegative || length < _minLength || length > _maxLength) {
      return null;
    }
    return IntroSegment(start, end);
  }

  /// Intro times for [key], or null when no service has them. Never throws.
  static Future<IntroSegment?> lookup(IntroKey key) async {
    if (_cache.containsKey(key.cacheKey)) return _cache[key.cacheKey];
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {'User-Agent': 'media-player/1.0'},
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
    final query = {
      'imdb_id': key.imdbId,
      'season': key.season,
      'episode': key.episode,
    };
    IntroSegment? found;
    var answered = false;
    try {
      final res = await dio.get<String>(
        'https://api.theintrodb.org/v2/media',
        queryParameters: query,
      );
      if (res.statusCode == 200 || res.statusCode == 404) answered = true;
      if (res.statusCode == 200) {
        found = parseTheIntroDb(jsonDecode(res.data ?? ''));
      }
    } catch (_) {}
    if (found == null) {
      try {
        final res = await dio.get<String>(
          'https://api.introdb.app/segments',
          queryParameters: query,
        );
        if (res.statusCode == 200 || res.statusCode == 404) answered = true;
        if (res.statusCode == 200) {
          found = parseIntroDb(jsonDecode(res.data ?? ''));
        }
      } catch (_) {}
    }
    dio.close();
    debugPrint(
      '[SKIP_INTRO] lookup s${key.season}e${key.episode} '
      '${found == null ? 'none' : '${found.start.inSeconds}-${found.end.inSeconds}s'}',
    );
    // A failed request is not "no intro": leave it out so a replay asks again.
    if (found != null || answered) {
      if (_cache.length >= _cacheCap) _cache.remove(_cache.keys.first);
      _cache[key.cacheKey] = found;
    }
    return found;
  }
}
