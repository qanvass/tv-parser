import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/m3u_parser.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/provider/external_ids.dart';
import 'package:mbark_iptv/repository/provider/media_metadata_enrichment_service.dart';
import 'package:mbark_iptv/repository/provider/provider_enums.dart';
import 'package:mbark_iptv/repository/provider/tmdb_client.dart';
import 'package:mbark_iptv/repository/provider/tmdb_enrichment_worker.dart';
import 'package:mbark_iptv/repository/provider/tmdb_match.dart';
import 'package:mbark_iptv/repository/provider/tmdb_metadata_cache.dart';
import 'package:mbark_iptv/repository/provider/title_normalizer.dart';
import 'package:mbark_iptv/repository/provider/unified_media_metadata.dart';

class _FakeTmdbHttp {
  final List<String> paths = [];
  Map<String, dynamic>? findBody;
  Map<String, dynamic>? searchBody;

  int get findCalls =>
      paths.where((p) => p.startsWith('/3/find/')).length;
  int get searchCalls =>
      paths.where((p) => p.startsWith('/3/search/movie')).length;

  Future<Map<String, dynamic>?> call(
    String path,
    Map<String, String> query,
  ) async {
    paths.add(path);
    if (path.startsWith('/3/find/')) return findBody;
    if (path.startsWith('/3/search/movie')) return searchBody;
    return null;
  }
}

Map<String, dynamic> _movieFindBody({int id = 321}) => {
      'movie_results': [
        {
          'id': id,
          'title': 'Deb Is Boss',
          'release_date': '2026-01-15',
          'poster_path': '/poster.jpg',
          'backdrop_path': '/back.jpg',
          'overview': 'A film.',
          'vote_average': 7.1,
        },
      ],
      'tv_results': [],
      'person_results': [],
      'tv_episode_results': [],
    };

Map<String, dynamic> _tvOnlyFindBody() => {
      'movie_results': [],
      'tv_results': [
        {
          'id': 99,
          'name': 'Deb Is Boss',
          'first_air_date': '2026-01-15',
          'poster_path': '/tv.jpg',
        },
      ],
      'person_results': [],
    };

Map<String, dynamic> _emptyFindBody() => {
      'movie_results': [],
      'tv_results': [],
    };

Map<String, dynamic> _titleSearchBody({int id = 456}) => {
      'results': [
        {
          'id': id,
          'title': 'Deb Is Boss',
          'release_date': '2026-01-15',
          'poster_path': '/search.jpg',
          'backdrop_path': '/searchb.jpg',
          'overview': 'From title search.',
          'vote_average': 6.5,
        },
      ],
    };

TmdbClient _client(_FakeTmdbHttp http) => TmdbClient(
      httpGet: http.call,
      enabledForTest: true,
    );

MediaMetadataEnrichmentService _enricher(TmdbClient client) =>
    MediaMetadataEnrichmentService(tmdb: client);

UnifiedMediaMetadata _provider({String? imdb}) => UnifiedMediaMetadata(
      title: 'Deb Is Boss (2026)',
      year: 2026,
      contentType: ContentType.movie,
      externalIds: ExternalIds(imdb: imdb),
    );

void main() {
  test('test process has no TMDB_API_KEY dart-define', () {
    expect(const String.fromEnvironment('TMDB_API_KEY'), isEmpty);
  });

  test('production TmdbClient stays disabled without a key', () {
    final client = TmdbClient();
    expect(client.isEnabled, isFalse);
  });

  test('disabled client never hits the injected HTTP layer', () async {
    var calls = 0;
    final client = TmdbClient(
      httpGet: (path, query) async {
        calls++;
        return {};
      },
    );
    expect(client.isEnabled, isFalse);
    expect(await client.findMovieByImdbId('tt27545912'), isNull);
    expect(await client.searchMovie('Deb Is Boss', year: 2026), isNull);
    expect(calls, 0);
  });

  group('IMDb id preserve', () {
    test('parser keeps valid tvg-id on ChannelMovie.imdbId, not the title', () {
      const body = '''
#EXTM3U
#EXTINF:-1 tvg-id="tt27545912" tvg-name="tt27545912" tvg-type="movies" group-title="Movies 2026",Deb Is Boss (2026)
https://cdn.example/movie/1
#EXTINF:-1 tvg-id="not-an-imdb" tvg-name="tt0000001" tvg-type="movies" group-title="Movies 2026",Other Title (2020)
https://cdn.example/movie/2
#EXTINF:-1 tvg-id="ttABC" tvg-name="nope" tvg-type="movies" group-title="Movies 2026",Bad Id (2020)
https://cdn.example/movie/3
''';
      final parsed = M3uParser.parseCatalog(
        body,
        forceEntryType: M3uEntryType.movie,
      );
      expect(parsed.movieChannels, hasLength(3));
      expect(parsed.movieChannels[0].imdbId, 'tt27545912');
      expect(parsed.movieChannels[0].name, 'Deb Is Boss (2026)');
      expect(parsed.movieChannels[1].imdbId, 'tt0000001');
      expect(parsed.movieChannels[1].name, 'Other Title (2020)');
      expect(parsed.movieChannels[2].imdbId, isNull);
      expect(parsed.movieChannels[2].name, 'Bad Id (2020)');
    });

    test('LocaleApi-shaped JSON: missing imdb_id stays null', () {
      final old = ChannelMovie.fromJson({
        'name': 'Legacy',
        'stream_id': 'm3u_stream_1',
      });
      expect(old.imdbId, isNull);
      expect(old.toJson().containsKey('imdb_id'), isFalse);
    });

    test('LocaleApi-shaped JSON: valid imdb_id round-trips', () {
      final movie = ChannelMovie.fromJson({
        'name': 'Deb Is Boss (2026)',
        'imdb_id': 'tt27545912',
      });
      expect(movie.imdbId, 'tt27545912');
      expect(movie.toJson()['imdb_id'], 'tt27545912');
    });

    test('malformed stored imdb_id is ignored', () {
      final movie = ChannelMovie.fromJson({'imdb_id': 'ttABC'});
      expect(movie.imdbId, isNull);
      expect(TmdbMatch.normalizeImdbId('tt'), isNull);
      expect(TmdbMatch.normalizeImdbId('27545912'), isNull);
    });
  });

  group('findMovieByImdbId + match order (mocked HTTP)', () {
    test('valid IMDb id returns movie → imdb match', () async {
      final http = _FakeTmdbHttp()..findBody = _movieFindBody();
      final meta = await _enricher(_client(http)).enrich(
        rawTitle: 'Deb Is Boss (2026)',
        contentType: ContentType.movie,
        provider: _provider(imdb: 'tt27545912'),
      );
      expect(http.findCalls, 1);
      expect(http.searchCalls, 0);
      expect(meta.matchMethod, 'imdb');
      expect(meta.source, MetadataSource.tmdb);
      expect(meta.externalIds.tmdb, '321');
      expect(meta.posterUrl, contains('poster.jpg'));
      expect(meta.backdropUrl, contains('back.jpg'));
    });

    test('IMDb returns TV only → reject as movie, then title/year', () async {
      final http = _FakeTmdbHttp()
        ..findBody = _tvOnlyFindBody()
        ..searchBody = _titleSearchBody();
      final meta = await _enricher(_client(http)).enrich(
        rawTitle: 'Deb Is Boss (2026)',
        contentType: ContentType.movie,
        provider: _provider(imdb: 'tt27545912'),
      );
      expect(http.findCalls, 1);
      expect(http.searchCalls, 1);
      expect(meta.matchMethod, 'title_year');
      expect(meta.externalIds.tmdb, '456');
    });

    test('IMDb returns no result → title/year fallback', () async {
      final http = _FakeTmdbHttp()
        ..findBody = _emptyFindBody()
        ..searchBody = _titleSearchBody();
      final meta = await _enricher(_client(http)).enrich(
        rawTitle: 'Deb Is Boss (2026)',
        contentType: ContentType.movie,
        provider: _provider(imdb: 'tt27545912'),
      );
      expect(http.findCalls, 1);
      expect(http.searchCalls, 1);
      expect(meta.matchMethod, 'title_year');
    });

    test('malformed IMDb ID → skip /find, title/year fallback', () async {
      final http = _FakeTmdbHttp()..searchBody = _titleSearchBody();
      final meta = await _enricher(_client(http)).enrich(
        rawTitle: 'Deb Is Boss (2026)',
        contentType: ContentType.movie,
        provider: _provider(imdb: 'ttABC'),
      );
      expect(http.findCalls, 0);
      expect(http.searchCalls, 1);
      expect(meta.matchMethod, 'title_year');
    });

    test('successful IMDb match → title search NOT called', () async {
      final http = _FakeTmdbHttp()
        ..findBody = _movieFindBody()
        ..searchBody = _titleSearchBody(id: 999);
      final meta = await _enricher(_client(http)).enrich(
        rawTitle: 'Deb Is Boss (2026)',
        contentType: ContentType.movie,
        provider: _provider(imdb: 'tt27545912'),
      );
      expect(http.searchCalls, 0);
      expect(meta.externalIds.tmdb, '321');
      expect(meta.matchMethod, 'imdb');
    });
  });

  group('cache key alignment', () {
    test('raw name with year and stripped display title share one key', () {
      const id = 'm3u_stream_1';
      final fromRaw = TmdbEnrichmentWorker.cacheKeyFor(
        'Deb Is Boss (2026)',
        id,
        type: ContentType.movie,
        year: 2026,
      );
      final fromDisplay = TmdbEnrichmentWorker.cacheKeyFor(
        'Deb Is Boss',
        id,
        type: ContentType.movie,
        year: 2026,
      );
      final enqueue = const TmdbEnqueueRequest(
        rawTitle: 'Deb Is Boss',
        type: ContentType.movie,
        providerId: id,
        year: 2026,
      );
      expect(fromRaw, fromDisplay);
      expect(enqueue.key, fromDisplay);
      expect(fromDisplay, contains('|2026'));
    });

    test('display title without year override used to miss the UI key', () {
      const id = 'm3u_stream_1';
      final uiOld = TmdbEnrichmentWorker.cacheKeyFor(
        'Deb Is Boss (2026)',
        id,
        type: ContentType.movie,
      );
      final enqueueOld = TmdbEnrichmentWorker.cacheKeyFor(
        'Deb Is Boss',
        id,
        type: ContentType.movie,
      );
      expect(uiOld, isNot(enqueueOld));
    });

    test('pre-parsed matchTitle emits the same key string', () {
      final parsed = TitleNormalizer.parse('Batman Caped Crusader S01E03 (2024)');
      final fromParse = TmdbEnrichmentWorker.cacheKeyFor(
        parsed.displayTitle,
        's1',
        type: ContentType.series,
        year: parsed.year,
      );
      final fromMatch = TmdbEnrichmentWorker.cacheKeyFor(
        parsed.displayTitle,
        's1',
        type: ContentType.series,
        year: parsed.year,
        matchTitle: parsed.matchTitle,
      );
      expect(fromMatch, fromParse);
      expect(fromMatch, 'series|s1|batman caped crusader|2024');
    });
  });

  group('worker cache', () {
    test('cached IMDb match → network NOT called again', () async {
      final http = _FakeTmdbHttp()..findBody = _movieFindBody();
      final client = _client(http);
      final dir = Directory.systemTemp.createTempSync('tmdb_imdb_cache_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final cache = TmdbMetadataCache(overrideDir: dir);
      final worker = TmdbEnrichmentWorker(
        client: client,
        cache: cache,
        enricher: _enricher(client),
        pumpDelay: Duration.zero,
      );
      const req = TmdbEnqueueRequest(
        rawTitle: 'Deb Is Boss (2026)',
        type: ContentType.movie,
        providerId: 'm3u_stream_1',
        year: 2026,
        imdbId: 'tt27545912',
      );
      await worker.ensureStarted();
      worker.enqueue(req);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(http.findCalls, 1);
      expect(cache.has(req.key), isTrue);
      expect(worker.lookup(req.key)?.matchMethod, 'imdb');

      worker.enqueue(req);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(http.findCalls, 1);
      expect(http.searchCalls, 0);
    });

    test('cache hit prioritize does not notify listeners', () async {
      final http = _FakeTmdbHttp()..findBody = _movieFindBody();
      final client = _client(http);
      final dir = Directory.systemTemp.createTempSync('tmdb_hit_skip_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final cache = TmdbMetadataCache(overrideDir: dir);
      final worker = TmdbEnrichmentWorker(
        client: client,
        cache: cache,
        enricher: _enricher(client),
        pumpDelay: Duration.zero,
      );
      const req = TmdbEnqueueRequest(
        rawTitle: 'Deb Is Boss (2026)',
        type: ContentType.movie,
        providerId: 'm3u_stream_1',
        year: 2026,
        imdbId: 'tt27545912',
      );
      await worker.ensureStarted();
      worker.enqueue(req);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cache.has(req.key), isTrue);

      var listenerFires = 0;
      worker.addListener(() => listenerFires++);
      final notifiesBefore = worker.debugNotifyCount;
      worker.prioritize(req);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(worker.debugCacheHitSkipCount, greaterThan(0));
      expect(worker.debugNotifyCount, notifiesBefore);
      expect(listenerFires, 0);
    });
  });
}
