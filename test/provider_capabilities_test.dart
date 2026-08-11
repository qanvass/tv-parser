import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/provider/m3u_header_inspector.dart';
import 'package:mbark_iptv/repository/provider/provider_capabilities.dart';
import 'package:mbark_iptv/repository/provider/provider_enums.dart';
import 'package:mbark_iptv/repository/provider/title_normalizer.dart';
import 'package:mbark_iptv/repository/provider/xtream_probe_url_builder.dart';

void main() {
  group('M3uHeaderInspector', () {
    test('extracts url-tvg from #EXTM3U header', () {
      const body = '''
#EXTM3U url-tvg="https://epg.example/xmltv.xml"
#EXTINF:-1 tvg-id="ch1",Channel One
http://cdn.example/live/1.ts
''';
      expect(
        M3uHeaderInspector.extractXmlTvUrl(body),
        'https://epg.example/xmltv.xml',
      );
    });

    test('extracts x-tvg-url and first of comma list', () {
      const body = '''
#EXTM3U x-tvg-url="https://a.example/epg.xml,https://b.example/epg.xml"
#EXTINF:-1,Test
http://x/1
''';
      expect(
        M3uHeaderInspector.extractXmlTvUrl(body),
        'https://a.example/epg.xml',
      );
    });

    test('returns null when header has no tvg url', () {
      const body = '''
#EXTM3U
#EXTINF:-1,Test
http://x/1
''';
      expect(M3uHeaderInspector.extractXmlTvUrl(body), isNull);
    });
  });

  group('ProviderCapabilities JSON', () {
    test('roundtrips', () {
      final caps = ProviderCapabilities(
        providerType: ProviderType.m3u,
        supportsLive: true,
        supportsXmlTv: true,
        supportsVod: false,
        xmlTvUrl: 'https://epg.example/x.xml',
        notes: const ['m3u_playlist', 'xmltv_header'],
        probedAt: DateTime.utc(2026, 7, 25, 12),
        liveStreamSample: 10,
      );
      final restored = ProviderCapabilities.fromJson(caps.toJson());
      expect(restored.providerType, ProviderType.m3u);
      expect(restored.supportsLive, isTrue);
      expect(restored.supportsXmlTv, isTrue);
      expect(restored.supportsVod, isFalse);
      expect(restored.xmlTvUrl, 'https://epg.example/x.xml');
      expect(restored.notes, contains('xmltv_header'));
      expect(restored.liveStreamSample, 10);
      expect(restored.capabilityLogLine, contains('live=true'));
      expect(restored.capabilityLogLine, isNot(contains('password')));
    });
  });

  group('TitleNormalizer', () {
    test('strips quality tags and extracts year', () {
      expect(
        TitleNormalizer.normalize('The Matrix (1999) 4K FHD'),
        'The Matrix',
      );
      expect(TitleNormalizer.extractYear('The Matrix (1999) 4K'), 1999);
      expect(
        TitleNormalizer.normalizeChannelId('CNN-US HD'),
        'cnnushd',
      );
    });
  });

  group('XtreamProbeUrlBuilder', () {
    test('normalizes bare host and strips player_api.php', () {
      expect(
        XtreamProbeUrlBuilder.normalizeHostBase('example.com'),
        'http://example.com',
      );
      expect(
        XtreamProbeUrlBuilder.normalizeHostBase('https://host:8080/c/'),
        'https://host:8080/c',
      );
      expect(
        XtreamProbeUrlBuilder.normalizeHostBase(
          'http://host/player_api.php',
        ),
        'http://host',
      );
    });

    test('builds player_api query without logging concern in test', () {
      final url = XtreamProbeUrlBuilder.playerApiUrl(
        hostBase: 'https://host:8080',
        username: 'u',
        password: 'p',
        action: 'get_live_categories',
      );
      expect(url, startsWith('https://host:8080/player_api.php?'));
      expect(url, contains('action=get_live_categories'));
      expect(url, contains('username=u'));
    });

    test('extracts credentials from /api/list/u/p path', () {
      final creds = XtreamProbeUrlBuilder.credentialsFromListPath(
        'http://cdn.example/api/list/alice/secretpass',
      );
      expect(creds, isNotNull);
      expect(creds!.$1, 'alice');
      expect(creds.$2, 'secretpass');
    });
  });
}
