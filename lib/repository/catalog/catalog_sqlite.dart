import 'package:sqflite/sqflite.dart';

import 'catalog_executor.dart';
import 'catalog_sql.dart';
import 'catalog_store.dart';

/// Opens the catalog database with the platform sqflite factory.
///
/// Android uses the device SQLite, which is why this file does not create
/// an FTS5 table.
class CatalogSqlite {
  static Future<CatalogStore> open(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      singleInstance: true,
      onCreate: (database, version) async {
        await database.execute(CatalogSql.createItems);
        await database.execute(CatalogSql.createStaging);
        await database.execute(CatalogSql.createMeta);
        await database.execute(CatalogSql.indexCategory);
        await database.execute(CatalogSql.indexName);
        await database.execute(CatalogSql.indexItem);
      },
    );
    return CatalogStore(_SqfliteCatalogExecutor(db));
  }

  static Future<void> deleteFile(String path) {
    return databaseFactory.deleteDatabase(path);
  }
}

class _SqfliteCatalogExecutor implements CatalogExecutor {
  _SqfliteCatalogExecutor(this._db);

  final Database _db;

  @override
  Future<void> execute(String sql, [List<Object?> args = const []]) {
    return _db.execute(sql, args);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final rows = await _db.rawQuery(sql, args);
    return [for (final row in rows) Map<String, Object?>.from(row)];
  }

  @override
  Future<void> insertRows(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final batch = _db.batch();
    for (final row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> transaction(List<CatalogStatement> statements) {
    return _db.transaction((txn) async {
      for (final statement in statements) {
        await txn.execute(statement.sql, statement.args);
      }
    });
  }

  @override
  Future<void> close() => _db.close();
}
