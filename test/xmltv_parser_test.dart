import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/epg/xmltv_parser.dart';
import 'package:mbark_iptv/repository/epg/xmltv_time.dart';
import 'package:mbark_iptv/repository/provider/epg_channel_matcher.dart';

void main() {
  group('XmlTvTime', () {
    test('parses UTC with space offset', () {
      final dt = XmlTvTime.parse('20260811021500 +0000');
      expect(dt, DateTime.utc(2026, 8, 11, 2, 15));
    });

    test('applies negative offset to UTC', () {
      final dt = XmlTvTime.parse('20260811021500 -0500');
      expect(dt, DateTime.utc(2026, 8, 11, 7, 15));
    });

    test('returns null for junk', () {
      expect(XmlTvTime.parse('not-a-time'), isNull);
      expect(XmlTvTime.parse(null), isNull);
    });
  });

  group('XmlTvParser', () {
    test('extracts channel and windowed programme', () {
      const xml = '''
<tv>
  <channel id="cnn.us">
    <display-name>CNN</display-name>
    <icon src="https://example.com/cnn.png"/>
  </channel>
  <programme start="20260811010000 +0000" stop="20260811020000 +0000" channel="cnn.us">
    <title>Morning News</title>
    <desc>Hourly headlines</desc>
  </programme>
  <programme start="20260811020000 +0000" stop="20260811030000 +0000" channel="cnn.us">
    <title>World Report</title>
  </programme>
  <programme start="20260810010000 +0000" stop="20260810020000 +0000" channel="cnn.us">
    <title>Yesterday</title>
  </programme>
</tv>
''';
      final result = XmlTvParser.parseXml(
        xml,
        windowStart: DateTime.utc(2026, 8, 11),
        windowEnd: DateTime.utc(2026, 8, 12),
      );
      expect(result.channelCount, 1);
      expect(result.channels['cnn.us']?.displayName, 'CNN');
      expect(result.programmeCount, 2);
      expect(result.programmes['cnn.us']!.first.title, 'Morning News');
      expect(
        result.programmes['cnn.us']!.any((p) => p.title == 'Yesterday'),
        isFalse,
      );
    });

    test('unescapes title entities', () {
      const xml = '''
<tv>
  <channel id="a.1"><display-name>A</display-name></channel>
  <programme start="20260811120000 +0000" stop="20260811130000 +0000" channel="a.1">
    <title>Tom &amp; Jerry</title>
  </programme>
</tv>
''';
      final result = XmlTvParser.parseXml(
        xml,
        windowStart: DateTime.utc(2026, 8, 11),
        windowEnd: DateTime.utc(2026, 8, 12),
      );
      expect(result.programmes['a.1']!.single.title, 'Tom & Jerry');
    });
  });

  group('EpgChannelMatcher', () {
    test('matches exact tvg-id then normalized', () {
      final m = EpgChannelMatcher();
      expect(
        m.match(epgChannelIds: const ['cnn.us'], tvgId: 'cnn.us'),
        'cnn.us',
      );
      expect(
        m.match(epgChannelIds: const ['CNN.us'], tvgId: 'cnnus'),
        'CNN.us',
      );
    });

    test('does not invent a match', () {
      final m = EpgChannelMatcher();
      expect(
        m.match(epgChannelIds: const ['cnn.us'], tvgId: 'espn.us'),
        isNull,
      );
    });
  });
}
