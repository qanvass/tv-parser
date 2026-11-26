import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/provider_curation_rules.dart';
import 'package:mbark_iptv/repository/models/category.dart';

List<String> names(List<CategoryModel> l) => l.map((c) => c.categoryName ?? '').toList();

void main() {
  test('Movies 2026 to 2023 come first, newest first; the rest keep their order', () {
    // Provider order as served (2021 sits second).
    final cats = [
      'Movies 2026', 'Movies 2021', 'Movies 2025', 'Movies 2024', 'Classics',
      'Movies 2023', 'Movies 2022', 'Recently Added', '4K Movies',
    ].asMap().entries.map((e) => CategoryModel(categoryId: '${e.key}', categoryName: e.value)).toList();

    expect(names(ProviderCurationRules.recentYearsFirst(cats)), [
      'Movies 2026', 'Movies 2025', 'Movies 2024', 'Movies 2023',
      'Movies 2021', 'Classics', 'Movies 2022', 'Recently Added', '4K Movies',
    ]);
  });

  test('no recent-year categories: order unchanged', () {
    final cats = ['Classics', 'Action', 'Movies 1999']
        .map((n) => CategoryModel(categoryId: n, categoryName: n))
        .toList();
    expect(names(ProviderCurationRules.recentYearsFirst(cats)), ['Classics', 'Action', 'Movies 1999']);
  });
}
