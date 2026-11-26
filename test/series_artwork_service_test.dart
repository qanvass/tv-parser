import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/provider/series_artwork_service.dart';
import 'package:mbark_iptv/repository/provider/tmdb_client.dart';

class _FakeHttp {
  final List<String> paths = [];
  String showName = 'Reasonable Doubt';
  String firstAir = '2022-09-27';
  bool failSeason = false;

  int count(String prefix) => paths.where((p) => p.startsWith(prefix)).length;

  Future<Map<String, dynamic>?> call(
    String path,
    Map<String, String> query,
  ) async {
    paths.add(path);
    if (path == '/3/search/tv') {
      return {
        'results': [
          {
            'id': 4242,
            'name': showName,
            'first_air_date': firstAir,
            'poster_path': '/p.jpg',
            'backdrop_path': '/b.jpg',
            'overview': 'A defence attorney in Los Angeles.',
            'vote_average': 7.4,
          },
        ],
      };
    }
    if (path == '/3/tv/4242') {
      return {
        'id': 4242,
        'name': showName,
        'first_air_date': firstAir,
        'last_air_date': '2025-01-10',
        'in_production': true,
        'poster_path': '/p.jpg',
        'backdrop_path': '/b.jpg',
        'genres': [
          {'id': 18, 'name': 'Drama'},
        ],
        'episode_run_time': [54],
        'number_of_seasons': 4,
      };
    }
    if (path == '/3/tv/4242/season/2') {
      if (failSeason) return null;
      return {
        'episodes': [
          {
            'episode_number': 1,
            'name': 'Can I Live?',
            'still_path': '/s1.jpg',
            'runtime': 52,
          },
          {'episode_number': 2, 'name': 'Second', 'still_path': null},
        ],
      };
    }
    return null;
  }
}

void main() {
  late Directory dir;
  late _FakeHttp http;

  SeriesArtworkService service() => SeriesArtworkService(
    client: TmdbClient(httpGet: http.call, enabledForTest: true),
    overrideDir: dir,
    retryDelay: Duration.zero,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('series_art_test');
    http = _FakeHttp();
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('matched show returns poster, backdrop, genres and years', () async {
    final art = await service().show(title: 'Reasonable Doubt (2022)');
    expect(art, isNotNull);
    expect(art!.tmdbId, '4242');
    expect(art.posterUrl, endsWith('/w500/p.jpg'));
    expect(art.backdropUrl, endsWith('/w1280/b.jpg'));
    expect(art.genres, ['Drama']);
    expect(art.year, 2022);
    expect(art.inProduction, isTrue);
    expect(art.runtimeMinutes, 54);
  });

  test('a different show with a similar name is not used', () async {
    http.showName = 'Reasonable Doubts';
    expect(await service().show(title: 'Reasonable Doubt (2022)'), isNull);
    expect(http.count('/3/tv/'), 0, reason: 'no details for a rejected hit');
  });

  test('same name from another decade is not used', () async {
    http.firstAir = '1991-09-26';
    expect(await service().show(title: 'Reasonable Doubt (2022)'), isNull);
  });

  test('identical requests in flight share one lookup', () async {
    final s = service();
    final both = await Future.wait([
      s.show(title: 'Reasonable Doubt (2022)'),
      s.show(title: 'Reasonable Doubt (2022)'),
    ]);
    expect(both[0], isNotNull);
    expect(http.count('/3/search/tv'), 1);
    expect(http.count('/3/tv/4242'), 1);
  });

  test('a second service reads the disk cache instead of the network',
      () async {
    await service().show(title: 'Reasonable Doubt (2022)');
    // Let the cache file land.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    http.paths.clear();
    final again = await service().show(title: 'Reasonable Doubt (2022)');
    expect(again?.tmdbId, '4242');
    expect(http.paths, isEmpty);
  });

  test('season lookup maps stills by episode number', () async {
    final eps = await service().season('4242', 2);
    expect(eps.keys, [1, 2]);
    expect(eps[1]!.name, 'Can I Live?');
    expect(eps[1]!.stillUrl, endsWith('/w300/s1.jpg'));
    expect(eps[1]!.runtimeMinutes, 52);
    expect(eps[2]!.stillUrl, isNull);
  });

  test('failed season lookup retries once, then stays quiet for a while',
      () async {
    http.failSeason = true;
    final s = service();
    expect(await s.season('4242', 2), isEmpty);
    expect(http.count('/3/tv/4242/season/2'), 2);
    expect(await s.season('4242', 2), isEmpty);
    expect(http.count('/3/tv/4242/season/2'), 2, reason: 'recent miss');
  });

  test('a provider TMDB id skips the title search', () async {
    final art = await service().show(title: 'Whatever', providerTmdbId: '4242');
    expect(art?.tmdbId, '4242');
    expect(http.count('/3/search/tv'), 0);
  });

  test('malformed ids never reach the network', () async {
    expect(await service().season('abc', 1), isEmpty);
    expect(http.paths, isEmpty);
  });
}
