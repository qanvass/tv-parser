import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/hls_vod_playlist.dart';

void main() {
  final base = Uri.parse('https://cdn.test/a/b/master.m3u8');
  const master = '''
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",DEFAULT=YES,URI="audio/en.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="sur",NAME="Atmos",DEFAULT=YES,URI="audio/atmos.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",URI="subs/en.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Arabic",URI="subs/ar.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=9,CODECS="avc1.4d4028,mp4a.40.2",AUDIO="aud",SUBTITLES="subs"
video/1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=8,CODECS="avc1.4d4028,ec-3",AUDIO="sur",SUBTITLES="subs"
video/1080s.m3u8
#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=1,URI="iframe.m3u8"
''';

  test('keeps video and one audio group, absolute links, no subtitles', () {
    final out = HlsVodPlaylist.trim(master, base)!;
    expect(out, contains('URI="https://cdn.test/a/b/audio/en.m3u8"'));
    expect(out, contains('https://cdn.test/a/b/video/1080.m3u8'));
    expect(out, isNot(contains('atmos')));
    expect(out, isNot(contains('1080s')));
    expect(out, isNot(contains('SUBTITLES')));
    expect(out, isNot(contains('iframe')));
  });

  test('drops SUBTITLES wherever it sits in the attribute list', () {
    const first = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",URI="subs/en.m3u8"
#EXT-X-STREAM-INF:SUBTITLES="subs",BANDWIDTH=9
video/1080.m3u8
''';
    final out = HlsVodPlaylist.trim(first, base)!;
    expect(out, isNot(contains('SUBTITLES')));
    expect(out, contains('#EXT-X-STREAM-INF:BANDWIDTH=9\n'));
  });

  test('leaves plain media and non-HLS bodies alone', () {
    expect(HlsVodPlaylist.trim('not a playlist', base), isNull);
    expect(HlsVodPlaylist.trim('#EXTM3U\n#EXTINF:6,\nseg0.ts\n', base), isNull);
    expect(
      HlsVodPlaylist.trim(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n',
        base,
      ),
      isNull,
    );
  });
}
