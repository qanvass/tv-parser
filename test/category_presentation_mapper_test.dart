import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/category_presentation_mapper.dart';

class _Movie {
  final String id;
  final int? year;

  const _Movie(this.id, [this.year]);
}

void main() {
  group('yearFromCategoryName', () {
    test('parses Movies / Movie / Films / VOD year buckets', () {
      expect(CategoryPresentationMapper.yearFromCategoryName('Movies 1915'), 1915);
      expect(CategoryPresentationMapper.yearFromCategoryName('Movie 2024'), 2024);
      expect(CategoryPresentationMapper.yearFromCategoryName('Films 2023'), 2023);
      expect(CategoryPresentationMapper.yearFromCategoryName('VOD 1998'), 1998);
      expect(CategoryPresentationMapper.yearFromCategoryName('2022 Movies'), 2022);
      expect(CategoryPresentationMapper.yearFromCategoryName('US MOVIES 2025'), 2025);
      expect(CategoryPresentationMapper.yearFromCategoryName('1916'), 1916);
    });

    test('does not treat plain Movies or genre names as years', () {
      expect(CategoryPresentationMapper.yearFromCategoryName('Movies'), isNull);
      expect(CategoryPresentationMapper.yearFromCategoryName('Action'), isNull);
      expect(CategoryPresentationMapper.yearFromCategoryName('Uncategorized'), isNull);
      expect(CategoryPresentationMapper.isYearBucketName('Movies 1920'), isTrue);
      expect(CategoryPresentationMapper.isYearBucketName('Comedy'), isFalse);
    });
  });

  group('presentMovies', () {
    PresentationSourceGroup<_Movie> group(
      String name,
      List<_Movie> items, {
      String? id,
    }) {
      return PresentationSourceGroup(
        providerCategoryId: id ?? name,
        providerCategoryName: name,
        items: items,
      );
    }

    test('collapses year buckets into Recently Added / Movies / Classics', () {
      final shelves = CategoryPresentationMapper.presentMovies<_Movie>(
        groups: [
          group('Movies 1915', [const _Movie('silent', 1915)]),
          group('Movies 1920', [const _Movie('golem', 1920)]),
          group('Movies 1998', [const _Movie('mid', 1998)]),
          group('Movies 2024', [const _Movie('new', 2024)]),
          group('Movies 2026', [const _Movie('newer', 2026)]),
        ],
        itemYear: (m) => m.year,
      );

      expect(
        shelves.map((s) => s.title).toList(),
        [
          CategoryPresentationMapper.shelfRecentlyAdded,
          CategoryPresentationMapper.shelfMovies,
          CategoryPresentationMapper.shelfClassics,
        ],
      );
      expect(shelves.every((s) => s.items.isNotEmpty), isTrue);
      expect(
        shelves
            .firstWhere(
              (s) => s.title == CategoryPresentationMapper.shelfClassics,
            )
            .items
            .map((m) => m.id),
        ['golem', 'silent'],
      );
      expect(
        shelves.any((s) => s.title.startsWith('Movies 19')),
        isFalse,
      );
    });

    test('uses category year when the item has no title year', () {
      final shelves = CategoryPresentationMapper.presentMovies<_Movie>(
        groups: [
          group('Movies 1916', [const _Movie('no-title-year')]),
        ],
        itemYear: (m) => m.year,
      );

      expect(shelves, hasLength(1));
      expect(shelves.single.title, CategoryPresentationMapper.shelfClassics);
      expect(shelves.single.items.single.id, 'no-title-year');
    });

    test('keeps non-year provider names and still collapses years', () {
      final shelves = CategoryPresentationMapper.presentMovies<_Movie>(
        groups: [
          group('Action', [const _Movie('a1')]),
          group('Movies 1970', [const _Movie('old', 1970)]),
        ],
        itemYear: (m) => m.year,
      );

      expect(
        shelves.map((s) => s.title).toList(),
        ['Action', CategoryPresentationMapper.shelfClassics],
      );
    });

    test('Phase 0: items with no year categories still yield Movies', () {
      final shelves = CategoryPresentationMapper.presentMovies<_Movie>(
        groups: [
          group('Movies', [const _Movie('x'), const _Movie('y')]),
        ],
      );

      expect(shelves, hasLength(1));
      expect(shelves.single.title, CategoryPresentationMapper.shelfMovies);
      expect(shelves.single.items, hasLength(2));
    });

    test('omits empty shelves and does not invent platform rows', () {
      final shelves = CategoryPresentationMapper.presentMovies<_Movie>(
        groups: [
          group('Movies 2025', [const _Movie('only-new', 2025)]),
        ],
        itemYear: (m) => m.year,
      );

      expect(shelves.map((s) => s.title), [
        CategoryPresentationMapper.shelfRecentlyAdded,
      ]);
      expect(
        shelves.any(
          (s) =>
              s.title.contains('Netflix') ||
              s.title.contains('Prime') ||
              s.title == CategoryPresentationMapper.shelfClassics,
        ),
        isFalse,
      );
    });

    test('empty input stays empty', () {
      expect(
        CategoryPresentationMapper.presentMovies<_Movie>(groups: const []),
        isEmpty,
      );
    });
  });
}
