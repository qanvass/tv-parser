import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/series_shelf_planner.dart';
import 'package:mbark_iptv/repository/models/category.dart';

CategoryModel _cat(String name, int i) =>
    CategoryModel(categoryId: 'c$i', categoryName: name, parentId: '0');

void main() {
  test('per-show playlists are shelved by year', () {
    final names = [
      'The Last of Us (2023)',
      'Medusa (2025)',
      'This Is Us (2016)',
      'Friends (1994)',
      'I Love Lucy (1951)',
      'Untitled Show',
      for (var i = 0; i < 30; i++) 'Show $i (2021)',
    ];
    final cats = [for (var i = 0; i < names.length; i++) _cat(names[i], i)];
    expect(SeriesShelfPlanner.looksPerShow(cats), isTrue);
    final plan = SeriesShelfPlanner.plan(cats, nowYear: 2026);
    expect(plan.map((p) => p.title).toList(), [
      'New & Recent',
      '2020s Series',
      '2010s Series',
      '1990s Series',
      'Classic Series',
      'More Series',
    ]);
    expect(plan.first.shows.single.categoryName, 'Medusa (2025)');
    expect(plan[1].shows.first.categoryName, 'The Last of Us (2023)');
    expect(SeriesShelfPlanner.showTitle(cats.first), 'The Last of Us');
  });

  test('genre-style categories are not treated as per-show', () {
    final cats = [
      for (var i = 0; i < 40; i++) _cat('Drama $i', i),
    ];
    expect(SeriesShelfPlanner.looksPerShow(cats), isFalse);
  });
}
