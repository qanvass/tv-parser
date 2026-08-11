import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/cinematic/playable_trailer_url.dart';

void main() {
  group('PlayableTrailerUrl', () {
    test('accepts direct http(s) video files only', () {
      expect(
        PlayableTrailerUrl.resolve('https://cdn.example/a.mp4'),
        'https://cdn.example/a.mp4',
      );
      expect(
        PlayableTrailerUrl.resolve('https://cdn.example/a.m3u8?token=1'),
        'https://cdn.example/a.m3u8?token=1',
      );
    });

    test('rejects YouTube ids, watch URLs, and search fallbacks', () {
      expect(PlayableTrailerUrl.resolve('dQw4w9WgXcQ'), isNull);
      expect(
        PlayableTrailerUrl.resolve('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        PlayableTrailerUrl.resolve(
          'https://www.youtube.com/results?search_query=official+trailer',
        ),
        isNull,
      );
    });

    test('rejects empty / non-http / extensionless URLs', () {
      expect(PlayableTrailerUrl.resolve(null), isNull);
      expect(PlayableTrailerUrl.resolve(''), isNull);
      expect(PlayableTrailerUrl.resolve('null'), isNull);
      expect(PlayableTrailerUrl.resolve('ftp://x.mp4'), isNull);
      expect(PlayableTrailerUrl.resolve('https://cdn.example/art.jpg'), isNull);
    });
  });
}
