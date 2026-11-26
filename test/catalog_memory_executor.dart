import 'package:mbark_iptv/repository/catalog/catalog_executor.dart';
import 'package:mbark_iptv/repository/catalog/catalog_sql.dart';

/// In-memory executor for the catalog SQL strings.
///
/// Unit tests run this instead of device SQLite. It honors the same
/// WHERE / ORDER BY / LIMIT / OFFSET statements the store sends.
class CatalogMemoryExecutor implements CatalogExecutor {
  final List<Map<String, Object?>> items = [];
  final List<Map<String, Object?>> staging = [];
  final Map<String, Map<String, Object?>> meta = {};
  final List<int> batchSizes = [];

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<Object?> args = const []]) async {
    if (sql == CatalogSql.deleteStaging) {
      staging.removeWhere((row) => row['kind'] == args[0]);
      return;
    }
    if (sql == CatalogSql.deleteLive) {
      items.removeWhere((row) => row['kind'] == args[0]);
      return;
    }
    if (sql == CatalogSql.copyStaging) {
      final kind = args[0];
      for (final row in staging) {
        if (row['kind'] == kind) {
          items.add(Map<String, Object?>.from(row));
        }
      }
      return;
    }
    if (sql == CatalogSql.upsertMeta) {
      meta[args[0]! as String] = {
        'ready': args[1],
        'row_count': args[2],
      };
      return;
    }
    throw StateError('unexpected catalog sql');
  }

  @override
  Future<void> insertRows(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    if (table != 'catalog_items_staging') {
      throw StateError('unexpected catalog table');
    }
    batchSizes.add(rows.length);
    for (final row in rows) {
      staging.removeWhere(
        (existing) =>
            existing['kind'] == row['kind'] &&
            existing['row_index'] == row['row_index'],
      );
      staging.add(Map<String, Object?>.from(row));
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    if (sql == CatalogSql.meta) {
      final row = meta[args[0]];
      if (row == null) return [];
      return [Map<String, Object?>.from(row)];
    }
    int rowIndex(Map<String, Object?> row) => row['row_index'] as int;
    List<Map<String, Object?>> ofKind(Object? kind) =>
        items.where((row) => row['kind'] == kind).toList()
          ..sort((a, b) => rowIndex(a).compareTo(rowIndex(b)));
    if (sql == CatalogSql.firstPerCategory) {
      final seen = <Object?>{};
      return [
        for (final row in ofKind(args[0]))
          if (seen.add(row['category_id'])) {'payload': row['payload']},
      ];
    }
    if (sql == CatalogSql.countPerCategory) {
      final counts = <Object?, int>{};
      for (final row in ofKind(args[0])) {
        counts[row['category_id']] = (counts[row['category_id']] ?? 0) + 1;
      }
      return [
        for (final entry in counts.entries)
          {'category_id': entry.key, 'n': entry.value},
      ];
    }
    if (sql == CatalogSql.allByCategory) {
      return [
        for (final row in ofKind(args[0]))
          if (row['category_id'] == args[1]) {'payload': row['payload']},
      ];
    }
    if (sql == CatalogSql.byPayloadFragment) {
      for (final row in ofKind(args[0])) {
        if ((row['payload']! as String).contains(args[1]! as String)) {
          return [
            {'payload': row['payload']},
          ];
        }
      }
      return [];
    }
    if (sql == CatalogSql.byItemId) {
      for (final row in ofKind(args[0])) {
        if (row['item_id'] == args[1]) {
          return [
            {'payload': row['payload']},
          ];
        }
      }
      return [];
    }
    final byCategory = sql == CatalogSql.pageByCategory;
    if (sql != CatalogSql.page && !byCategory) {
      throw StateError('unexpected catalog query');
    }
    final kind = args[0];
    final category = byCategory ? args[1] : null;
    final limit = (byCategory ? args[2] : args[1]) as int;
    final offset = (byCategory ? args[3] : args[2]) as int;
    final matched =
        items.where((row) {
          if (row['kind'] != kind) return false;
          if (byCategory && row['category_id'] != category) return false;
          return true;
        }).toList()..sort(
          (a, b) => (a['row_index'] as int).compareTo(b['row_index'] as int),
        );
    final start = offset < 0 ? 0 : offset;
    if (limit <= 0 || start >= matched.length) return [];
    return [
      for (final row in matched.skip(start).take(limit))
        {'payload': row['payload']},
    ];
  }

  @override
  Future<void> transaction(List<CatalogStatement> statements) async {
    final itemsCopy = [for (final row in items) Map<String, Object?>.from(row)];
    final stagingCopy = [
      for (final row in staging) Map<String, Object?>.from(row),
    ];
    final metaCopy = {
      for (final entry in meta.entries)
        entry.key: Map<String, Object?>.from(entry.value),
    };
    try {
      for (final statement in statements) {
        await execute(statement.sql, statement.args);
      }
    } catch (_) {
      items
        ..clear()
        ..addAll(itemsCopy);
      staging
        ..clear()
        ..addAll(stagingCopy);
      meta
        ..clear()
        ..addAll(metaCopy);
      rethrow;
    }
  }
}
