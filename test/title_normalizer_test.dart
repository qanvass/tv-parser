import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/provider/title_normalizer.dart';
import 'package:mbark_iptv/repository/provider/tmdb_match.dart';

void main() {
  group('TitleNormalizer.parse', () {
    test('strips year parens and quality without inventing a title', () {
      final p = TitleNormalizer.parse('The Golem (1920) 1080p');
      expect(p.displayTitle, 'The Golem');
      expect(p.year, 1920);
      expect(p.qualityLabel, 'HD');
    });

    test('extracts SxxExx and keeps the series name', () {
      final p = TitleNormalizer.parse('Batman: Caped Crusader S01E03');
      expect(p.displayTitle, 'Batman: Caped Crusader');
      expect(p.season, 1);
      expect(p.episode, 3);
      expect(p.episodeBadge, 'S1:E3');
    });

    test('parses bracket episode tokens', () {
      final p = TitleNormalizer.parse('Love Island [S01 E01]');
      expect(p.displayTitle, 'Love Island');
      expect(p.season, 1);
      expect(p.episode, 1);
    });

    test('does not invent a different title', () {
      final p = TitleNormalizer.parse('Some Obscure Show');
      expect(p.displayTitle, 'Some Obscure Show');
      expect(p.year, isNull);
      expect(p.season, isNull);
    });
  });

  group('TmdbMatch', () {
    test('accepts exact sanitized title with matching year', () {
      expect(
        TmdbMatch.isHighConfidence(
          queryTitle: 'The Golem (1920)',
          resultTitle: 'The Golem',
          queryYear: 1920,
          resultYear: 1920,
        ),
        isTrue,
      );
    });

    test('rejects year mismatch', () {
      expect(
        TmdbMatch.isHighConfidence(
          queryTitle: 'The Golem',
          resultTitle: 'The Golem',
          queryYear: 1920,
          resultYear: 2018,
        ),
        isFalse,
      );
    });

    test('rejects different titles', () {
      expect(
        TmdbMatch.isHighConfidence(
          queryTitle: 'The Golem',
          resultTitle: 'Fragments of Tomorrow',
          queryYear: null,
          resultYear: null,
        ),
        isFalse,
      );
    });
  });

  group('series group key', () {
    test('episodes of the same show share a key', () {
      expect(
        TitleNormalizer.seriesGroupKey('Batman Caped Crusader S01E01'),
        TitleNormalizer.seriesGroupKey('Batman Caped Crusader S01E05'),
      );
    });
  });
}
