import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/remote_watch_service.dart';

void main() {
  ({String item, int rank})? pick(String q, List<String> names) =>
      RemoteWatchService.pickBest<String>(q, names, (n) => n);

  group('spokenName', () {
    test('drops region prefixes and quality tags', () {
      expect(RemoteWatchService.spokenName('US: CNN HD'), 'cnn');
      expect(RemoteWatchService.spokenName('USA | CNN FHD'), 'cnn');
      expect(RemoteWatchService.spokenName('[US] ESPN 2 (4K)'), 'espn 2');
      expect(RemoteWatchService.spokenName('UK: US: Fox News'), 'fox news');
    });

    test('drops a trailing year on movies', () {
      expect(RemoteWatchService.spokenName('Heat (1995)'), 'heat');
      expect(RemoteWatchService.spokenName('Heat - 1995'), 'heat');
      expect(
        RemoteWatchService.spokenName('Blade Runner 2049'),
        'blade runner 2049',
      );
    });
  });

  group('pickBest', () {
    test('exact channel beats an earlier longer name', () {
      final got = pick('CNN', ['CNN International HD', 'US: CNN HD', 'CNN en Español']);
      expect(got?.item, 'US: CNN HD');
      expect(got?.rank, 0);
    });

    test('prefix match when there is no exact one', () {
      final got = pick('fox', ['Sky Fox Docs', 'FOX News HD', 'FOX Sports 1']);
      expect(got?.item, 'FOX News HD');
      expect(got?.rank, 1);
    });

    test('falls back to the top search hit', () {
      final got = pick('weather', ['The Weather Channel', 'AccuWeather']);
      expect(got?.item, 'The Weather Channel');
      expect(got?.rank, 2);
    });

    test('the main channel beats other editions and country tags', () {
      final got = pick('CNN', [
        'CNN Espanol US',
        'CNN International',
        'CNN US',
        'CNN HD USA',
      ]);
      expect(got?.item, 'CNN US');
      expect(got?.rank, 0);
      final noExact = pick('CNN', ['CNN Espanol US', 'CNN Headline News']);
      expect(noExact?.item, 'CNN Headline News');
      final asked = pick('CNN Espanol', ['CNN US', 'CNN Espanol US']);
      expect(asked?.item, 'CNN Espanol US');
      expect(RemoteWatchService.spokenName('US CNN'), 'cnn');
    });

    test('other matches are offered by name', () {
      expect(
        RemoteWatchService.otherNames<String>(
          ['CNN US', 'CNN Espanol US', 'CNN US', 'CNN International'],
          'CNN US',
          (n) => n,
        ),
        ['CNN Espanol US', 'CNN International'],
      );
    });

    test('a made-up name finds nothing instead of something else', () {
      expect(
        pick('Zzyzx Qwerty Channel', ['Channel 5', 'Cooking Channel US']),
        isNull,
      );
      expect(pick('weather channel', ['The Weather Channel US'])?.rank, 2);
    });

    test('numbered event feeds lose to the real channel', () {
      final feeds = [for (var i = 470; i < 600; i++) 'ESPN 0$i'];
      expect(pick('ESPN', [...feeds, 'ESPN US'])?.item, 'ESPN US');
      expect(pick('ESPN', [...feeds, 'ESPN 2 US'])?.item, 'ESPN 2 US');
      expect(pick('ESPN', feeds)?.item, 'ESPN 0470');
    });

    test('nothing to pick from', () {
      expect(pick('cnn', const []), isNull);
      expect(pick('  ', ['CNN']), isNull);
    });
  });

  group('series', () {
    test('season and episode labels', () {
      expect(RemoteWatchService.firstNumber('Season 02'), 2);
      expect(RemoteWatchService.firstNumber('specials'), isNull);
      expect(RemoteWatchService.numberedIndex(['1', '2', '4'], 4), 2);
      expect(RemoteWatchService.numberedIndex(['1', '2', '4'], 3), -1);
      expect(
        RemoteWatchService.numberedIndex(['', ''], 2, byPosition: true),
        1,
      );
      expect(
        RemoteWatchService.numberedIndex(['1', '2'], 9, byPosition: true),
        -1,
      );
    });

    test('a season or episode number makes it a series request', () {
      final c = RemoteWatchCommand.fromMap({
        'query': 'Seinfeld',
        'kind': 'any',
        'season': '3',
        'episode': '5',
      })!;
      expect(c.kind, 'series');
      expect(c.season, 3);
      expect(c.episode, 5);
      final plain = RemoteWatchCommand.fromMap({
        'query': 'Seinfeld',
        'kind': 'show',
        'season': '',
        'episode': 'x',
      })!;
      expect(plain.kind, 'series');
      expect(plain.season, isNull);
      expect(plain.episode, isNull);
    });
  });

  group('RemoteWatchCommand', () {
    test('parses kinds and rejects empty queries', () {
      expect(RemoteWatchCommand.fromMap({'query': ' CNN ', 'kind': 'Channel'})?.kind, 'live');
      expect(RemoteWatchCommand.fromMap({'query': 'Heat', 'kind': 'film'})?.kind, 'movie');
      expect(RemoteWatchCommand.fromMap({'query': 'Heat'})?.kind, 'any');
      expect(RemoteWatchCommand.fromMap({'query': '  '}), isNull);
      expect(RemoteWatchCommand.fromMap('CNN'), isNull);
    });

    test('old commands are stale, unknown ids are not', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1795000000000);
      RemoteWatchCommand cmd(String id) =>
          RemoteWatchCommand(id: id, kind: 'any', query: 'CNN');
      expect(cmd('${1795000000000 - 10000}-ab').isStale(now), isFalse);
      expect(cmd('${1795000000000 - 600000}-ab').isStale(now), isTrue);
      expect(cmd('').isStale(now), isFalse);
    });
  });
}
