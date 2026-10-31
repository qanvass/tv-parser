class CatalogStatement {
  final String sql;
  final List<Object?> args;

  const CatalogStatement(this.sql, [this.args = const []]);
}

/// The small set of statements the catalog store runs.
abstract class CatalogExecutor {
  Future<void> execute(String sql, [List<Object?> args = const []]);

  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> args = const [],
  ]);

  Future<void> insertRows(String table, List<Map<String, Object?>> rows);

  Future<void> transaction(List<CatalogStatement> statements);

  Future<void> close();
}
