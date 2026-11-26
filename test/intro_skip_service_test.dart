import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/hls_vod_playlist.dart';
import 'package:mbark_iptv/repository/api/intro_skip_service.dart';

void main() {
  group('episode key from stream address', () {
    test('playlist episode address gives imdb id, season, episode', () {
      final k = IntroSkipService.keyFromUrl(
        'https://host.test/api/stream/u/p/tvshow/tt11231226/2/2',
      )!;
      expect(k.imdbId, 'tt11231226');
      expect(k.season, 2);
      expect(k.episode, 2);
    });

    test('addresses without an imdb id give no key', () {
      expect(
        IntroSkipService.keyFromUrl('http://h.test/series/u/p/123.m3u8'),
        isNull,
      );
      expect(
        IntroSkipService.keyFromUrl('https://h.test/tvshow/abc/1/1'),
        isNull,
      );
    });
  });

  group('service answers', () {
    test('TheIntroDB intro list', () {
      final s = IntroSkipService.parseTheIntroDb({
        'intro': [
          {'start_ms': 238405, 'end_ms': 291959},
        ],
      })!;
      expect(s.start.inMilliseconds, 238405);
      expect(s.end.inMilliseconds, 291959);
    });

    test('IntroDB segment object', () {
      final s = IntroSkipService.parseIntroDb({
        'intro': {'start_ms': 6000, 'end_ms': 105000},
      })!;
      expect(s.start.inSeconds, 6);
      expect(s.end.inSeconds, 105);
    });

    test('missing, open-ended or absurd intros are rejected', () {
      expect(IntroSkipService.parseTheIntroDb({'intro': []}), isNull);
      expect(IntroSkipService.parseIntroDb({'intro': null}), isNull);
      expect(
        IntroSkipService.parseTheIntroDb({
          'intro': [
            {'start_ms': 1000, 'end_ms': null},
          ],
        }),
        isNull,
      );
      expect(
        IntroSkipService.parseIntroDb({
          'intro': {'start_ms': 0, 'end_ms': 3600000},
        }),
        isNull,
      );
      expect(
        IntroSkipService.parseIntroDb({
          'intro': {'start_ms': 5000, 'end_ms': 6000},
        }),
        isNull,
      );
    });
  });

  test('button window is the intro, not before and not at its very end', () {
    const s = IntroSegment(Duration(seconds: 238), Duration(seconds: 292));
    expect(s.covers(const Duration(seconds: 100)), isFalse);
    expect(s.covers(const Duration(seconds: 237)), isTrue);
    expect(s.covers(const Duration(seconds: 260)), isTrue);
    expect(s.covers(const Duration(seconds: 291)), isFalse);
    expect(s.covers(const Duration(seconds: 400)), isFalse);
  });

  group('single quality', () {
    final base = Uri.parse('https://cdn.test/a/master.m3u8');
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=854x480,CODECS="avc1"
v/480.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="hvc1"
v/1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=9000000,RESOLUTION=2560x1440,CODECS="hvc1"
v/1440.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=16000000,RESOLUTION=3840x2160,CODECS="hvc1"
v/2160.m3u8
''';

    List<String> variants(String out) => [
      for (final l in out.split('\n'))
        if (l.startsWith('https://')) l,
    ];

    test('1080p cap keeps only the 1080p variant', () {
      final out = HlsVodPlaylist.trim(master, base, maxHeight: 1080)!;
      expect(variants(out), ['https://cdn.test/a/v/1080.m3u8']);
      expect('#EXT-X-STREAM-INF'.allMatches(out).length, 1);
    });

    test('4K cap keeps 4K; 720p cap falls to the tallest that fits', () {
      expect(variants(HlsVodPlaylist.trim(master, base, maxHeight: 2160)!), [
        'https://cdn.test/a/v/2160.m3u8',
      ]);
      expect(variants(HlsVodPlaylist.trim(master, base, maxHeight: 720)!), [
        'https://cdn.test/a/v/480.m3u8',
      ]);
    });

    test('nothing fits: the shortest variant is kept', () {
      expect(variants(HlsVodPlaylist.trim(master, base, maxHeight: 240)!), [
        'https://cdn.test/a/v/480.m3u8',
      ]);
    });

    test('same height: higher bitrate wins; no sizes: highest bitrate', () {
      expect(
        HlsVodPlaylist.pickVariant([
          '#EXT-X-STREAM-INF:BANDWIDTH=4,RESOLUTION=1920x1080',
          '#EXT-X-STREAM-INF:BANDWIDTH=7,RESOLUTION=1920x1080',
        ], 1080),
        1,
      );
      expect(
        HlsVodPlaylist.pickVariant([
          '#EXT-X-STREAM-INF:BANDWIDTH=4',
          '#EXT-X-STREAM-INF:BANDWIDTH=9',
          '#EXT-X-STREAM-INF:BANDWIDTH=7',
        ], 1080),
        1,
      );
    });

    test('without a cap every variant stays', () {
      expect(HlsVodPlaylist.trim(master, base), isNull);
    });
  });
}
