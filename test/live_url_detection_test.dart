import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/screens/screens.dart';

void main() {
  group('isLikelyLiveStreamUrl', () {
    test('Xtream movies served as HLS are not live', () {
      expect(isLikelyLiveStreamUrl('http://10.0.0.68:8080/movie/u/p/11378946.m3u8'), isFalse);
      expect(isLikelyLiveStreamUrl('http://host:8080/movie/u/p/42.mp4'), isFalse);
    });

    test('Xtream episodes are not live', () {
      expect(isLikelyLiveStreamUrl('http://host:8080/series/u/p/777.m3u8'), isFalse);
      expect(isLikelyLiveStreamUrl('http://host:8080/series/u/p/777.mkv'), isFalse);
    });

    test('live channels stay live', () {
      expect(isLikelyLiveStreamUrl('http://host:8080/live/u/p/123.ts'), isTrue);
      expect(isLikelyLiveStreamUrl('http://host:8080/live/u/p/123.m3u8'), isTrue);
      expect(isLikelyLiveStreamUrl('https://provider.example/api/stream/abc/index.m3u8'), isTrue);
      expect(isLikelyLiveStreamUrl('https://cdn.example/channel/index.m3u8'), isTrue);
    });
  });
}
