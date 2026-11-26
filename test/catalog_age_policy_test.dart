import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/provider/catalog_age_policy.dart';
import 'package:mbark_iptv/repository/provider/running_series_data.dart';

void main() {
  // A small stand-in for the generated list: [first year, first season kept].
  const running = <String, List<int>>{
    'thesimpsons': [1989, 32],
    'strangerthings': [2016, 4],
    'lawandorderspecialvictimsunit': [1999, 22],
    'thetwilightzone': [1959, 1, 2019, 2],
  };
  int verdict(String name, {String? group, int? startYear}) =>
      CatalogAgePolicy.seriesVerdict(
        name,
        group: group,
        startYear: startYear,
        running: running,
      );
  bool gone(String name, {String? group, int? startYear}) =>
      CatalogAgePolicy.seriesRowTooOld(
        name,
        group: group,
        startYear: startYear,
        running: running,
      );

  group('series', () {
    test('2020 and later is kept whole', () {
      expect(verdict('Ted Lasso (2020) S01 E01'), CatalogAgePolicy.keepAll);
      expect(verdict('Severance S01 E01', group: '2020s Series'), 0);
      expect(verdict('Anything', startYear: 2024), 0);
    });

    test('before 2020 and not running is dropped', () {
      expect(verdict('Breaking Bad (2008) S01 E01'), CatalogAgePolicy.dropShow);
      expect(gone('Breaking Bad S02 E03', group: '2000s Series'), isTrue);
      expect(gone('Cheers S01 E01', group: 'Cheers [1982]'), isTrue);
      expect(gone('Seinfeld', startYear: 1989), isTrue);
    });

    test('still running: kept, from its first 2020 season', () {
      expect(verdict('The Simpsons (1989) S01 E01'), 32);
      expect(gone('The Simpsons (1989) S31 E22'), isTrue);
      expect(gone('The Simpsons (1989) S32 E01'), isFalse);
      expect(gone('Stranger Things S03 E08', group: '2010s Series'), isTrue);
      expect(gone('Stranger Things S04 E01', group: '2010s Series'), isFalse);
      // The show row itself (no episode tag) stays.
      expect(gone('Stranger Things', group: '2010s Series'), isFalse);
      expect(
        gone('Law & Order: Special Victims Unit S25 E01', group: '1990s Series'),
        isFalse,
      );
    });

    test('same title, different show: the start year decides', () {
      expect(verdict('The Twilight Zone (1959)'), 1);
      expect(verdict('The Twilight Zone (2019)'), 2);
      expect(verdict('The Twilight Zone (1985)'), CatalogAgePolicy.dropShow);
      expect(
        verdict('Stranger Things', group: '1990s Series'),
        CatalogAgePolicy.dropShow,
      );
    });

    test('age not known: kept', () {
      expect(verdict('Seinfeld S01 E01', group: 'Comedy'), 0);
      expect(verdict('1923 S01 E01', group: 'New & Recent'), 0);
      expect(verdict('Space 1999'), 0);
    });

    test('without the list only pre-2000 shows are dropped', () {
      int bare(String n, {String? group}) => CatalogAgePolicy.seriesVerdict(
        n,
        group: group,
        running: const <String, List<int>>{},
      );
      expect(bare('Cheers (1982)'), CatalogAgePolicy.dropShow);
      expect(bare('ER', group: '1990s Series'), CatalogAgePolicy.dropShow);
      expect(bare('Breaking Bad (2008)'), CatalogAgePolicy.keepAll);
    });

    test('season labels', () {
      expect(CatalogAgePolicy.seasonKept('3', 4), isFalse);
      expect(CatalogAgePolicy.seasonKept('Season 04', 4), isTrue);
      expect(CatalogAgePolicy.seasonKept('Specials', 4), isTrue);
      expect(CatalogAgePolicy.seasonKept('1', CatalogAgePolicy.keepAll), isTrue);
    });
  });

  group('the generated list', () {
    test('is there and reads as expected', () {
      expect(runningSeriesBefore2020.length, greaterThan(1000));
      expect(runningSeriesBefore2020.values.every((v) => v.length.isEven), isTrue);
      expect(CatalogAgePolicy.seriesVerdict('The Simpsons (1989)'), greaterThan(1));
      expect(
        CatalogAgePolicy.seriesVerdict('Breaking Bad (2008)'),
        CatalogAgePolicy.dropShow,
      );
      expect(CatalogAgePolicy.titleKey('Law & Order: SVU'), 'lawandordersvu');
    });
  });

  group('movies', () {
    test('before 2020 are dropped', () {
      expect(CatalogAgePolicy.movieTooOld('Heat (1995)'), isTrue);
      expect(CatalogAgePolicy.movieTooOld('Inception (2010)'), isTrue);
      expect(CatalogAgePolicy.movieTooOld('Arrival', '2010s Movies'), isTrue);
      expect(CatalogAgePolicy.movieTooOld('Tenet (2020)'), isFalse);
      expect(CatalogAgePolicy.movieTooOld('Dune', '2020s Movies'), isFalse);
    });

    test('age not known: kept', () {
      expect(CatalogAgePolicy.movieTooOld('Blade Runner 2049'), isFalse);
      expect(CatalogAgePolicy.movieTooOld('Heat', 'Classics'), isFalse);
      expect(CatalogAgePolicy.movieTooOld(null), isFalse);
    });
  });
}
