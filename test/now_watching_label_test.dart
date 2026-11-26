import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/shared/widgets/now_watching_lower_third.dart';

void main() {
  test('episode name gives the show and season/episode', () {
    final l = nowWatchingLabel('Reasonable Doubt (2022) S02 E02');
    expect(l.title, 'Reasonable Doubt');
    expect(l.detail, 'S2 E2');
  });

  test('movie name gives the title and year', () {
    final l = nowWatchingLabel('Reckless (2026)');
    expect(l.title, 'Reckless');
    expect(l.detail, '2026');
  });

  test('movie without a year has no detail', () {
    final l = nowWatchingLabel('Sintel');
    expect(l.title, 'Sintel');
    expect(l.detail, isNull);
  });

  test('placeholder names are never shown as a title', () {
    for (final name in ['TV Stream', 'Movie', 'Episode', '  ', 'tv parser']) {
      expect(nowWatchingLabel(name).title, isEmpty, reason: name);
    }
  });
}
