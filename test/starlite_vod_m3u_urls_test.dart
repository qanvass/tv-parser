import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/m3u_parser.dart';
import 'package:mbark_iptv/repository/api/starlite_vod_m3u_urls.dart';

void main() {
  group('StarliteVodM3uUrls.listBaseUrl', () {
    test('strips /m3u8/livetv suffix', () {
      expect(
        StarliteVodM3uUrls.listBaseUrl(
          'https://starlite.best/api/list/user1/pass1/m3u8/livetv',
        ),
        'https://starlite.best/api/list/user1/pass1',
      );
    });

    test('accepts bare /api/list/u/p', () {
      expect(
        StarliteVodM3uUrls.listBaseUrl(
          'https://tvnow.best/api/list/alice/secret',
        ),
        'https://tvnow.best/api/list/alice/secret',
      );
    });

    test('strips /m3u8/movies when used as source', () {
      expect(
        StarliteVodM3uUrls.listBaseUrl(
          'https://example.com/api/list/u/p/m3u8/movies',
        ),
        'https://example.com/api/list/u/p',
      );
    });

    test('returns null without /api/list/', () {
      expect(
        StarliteVodM3uUrls.listBaseUrl('https://cdn.example/get.php?id=1'),
        isNull,
      );
    });
  });

  group('StarliteVodM3uUrls movies / tvshows builders', () {
    const live = 'https://starlite.best/api/list/u/p/m3u8/livetv';

    test('moviesUrl', () {
      expect(
        StarliteVodM3uUrls.moviesUrl(live),
        'https://starlite.best/api/list/u/p/m3u8/movies',
      );
    });

    test('tvShowsUrl shard 1 omits number', () {
      expect(
        StarliteVodM3uUrls.tvShowsUrl(live),
        'https://starlite.best/api/list/u/p/m3u8/tvshows',
      );
      expect(
        StarliteVodM3uUrls.tvShowsUrl(live, 1),
        'https://starlite.best/api/list/u/p/m3u8/tvshows',
      );
    });

    test('tvShowsUrl shard N appends /N', () {
      expect(
        StarliteVodM3uUrls.tvShowsUrl(live, 2),
        'https://starlite.best/api/list/u/p/m3u8/tvshows/2',
      );
      expect(
        StarliteVodM3uUrls.tvShowsUrl(live, 14),
        'https://starlite.best/api/list/u/p/m3u8/tvshows/14',
      );
    });

    test('tvShowsShardUrls ordered 1..max', () {
      final urls = StarliteVodM3uUrls.tvShowsShardUrls(live, maxShards: 3);
      expect(urls, [
        'https://starlite.best/api/list/u/p/m3u8/tvshows',
        'https://starlite.best/api/list/u/p/m3u8/tvshows/2',
        'https://starlite.best/api/list/u/p/m3u8/tvshows/3',
      ]);
    });

    test('defaultXmlTvUrl for known hosts', () {
      expect(
        StarliteVodM3uUrls.defaultXmlTvUrl(live),
        'https://epg.starlite.best/utc.xml.gz',
      );
      expect(
        StarliteVodM3uUrls.defaultXmlTvUrl(
          'https://tvnow.best/api/list/u/p',
        ),
        'https://epg.starlite.best/utc.xml.gz',
      );
    });
  });

  group('StarliteVodM3uUrls shard stop logic', () {
    const bodyA = '''
#EXTM3U
#EXTINF:-1 group-title="Show A",Ep 1
https://cdn.example/api/stream/a1
''';
    const bodyB = '''
#EXTM3U
#EXTINF:-1 group-title="Show B",Ep 1
https://cdn.example/api/stream/b1
''';

    test('continues on distinct successful shard', () {
      final seen = <String>{};
      expect(
        StarliteVodM3uUrls.reasonToStop(
          statusCode: 200,
          body: bodyA,
          seenFingerprints: seen,
        ),
        StarliteVodShardStop.none,
      );
      seen.add(StarliteVodM3uUrls.bodyFingerprint(bodyA));
      expect(
        StarliteVodM3uUrls.reasonToStop(
          statusCode: 200,
          body: bodyB,
          seenFingerprints: seen,
        ),
        StarliteVodShardStop.none,
      );
    });

    test('stops on duplicate fingerprint', () {
      final seen = {StarliteVodM3uUrls.bodyFingerprint(bodyA)};
      expect(
        StarliteVodM3uUrls.reasonToStop(
          statusCode: 200,
          body: bodyA,
          seenFingerprints: seen,
        ),
        StarliteVodShardStop.duplicate,
      );
    });

    test('stops on 404 / empty / not m3u', () {
      expect(
        StarliteVodM3uUrls.reasonToStop(
          statusCode: 404,
          body: bodyA,
          seenFingerprints: {},
        ),
        StarliteVodShardStop.http404,
      );
      expect(
        StarliteVodM3uUrls.reasonToStop(
          statusCode: 200,
          body: '#EXTM3U\n',
          seenFingerprints: {},
        ),
        StarliteVodShardStop.empty,
      );
      expect(
        StarliteVodM3uUrls.reasonToStop(
          statusCode: 200,
          body: '<html>nope</html>',
          seenFingerprints: {},
        ),
        StarliteVodShardStop.notM3u,
      );
    });

    test('countExtinf', () {
      expect(StarliteVodM3uUrls.countExtinf(bodyA), 1);
      expect(StarliteVodM3uUrls.countExtinf(null), 0);
    });
  });

  group('M3uParser forceEntryType for VOD M3U', () {
    test('forces movie despite /api/stream/ live-looking URLs', () {
      const body = '''
#EXTM3U
#EXTINF:-1 tvg-logo="" group-title="Movies 2026",Film One
https://cdn.example/api/stream/movie.epg/x
#EXTINF:-1 group-title="Movies 2024",Film Two
https://cdn.example/api/stream/y
''';
      final parsed = M3uParser.parseCatalog(
        body,
        forceEntryType: M3uEntryType.movie,
      );
      expect(parsed.movieChannels.length, 2);
      expect(parsed.liveChannels, isEmpty);
      expect(parsed.seriesChannels, isEmpty);
      expect(parsed.movieCategories.length, 2);
    });

    test('forces series for show-title groups', () {
      const body = '''
#EXTM3U
#EXTINF:-1 group-title="Some Show",S01E01
https://cdn.example/api/stream/s1
#EXTINF:-1 group-title="Some Show",S01E02
https://cdn.example/api/stream/s2
''';
      final parsed = M3uParser.parseCatalog(
        body,
        forceEntryType: M3uEntryType.series,
      );
      expect(parsed.seriesChannels.length, 2);
      expect(parsed.liveChannels, isEmpty);
      expect(parsed.seriesCategories.length, 1);
    });
  });
}
