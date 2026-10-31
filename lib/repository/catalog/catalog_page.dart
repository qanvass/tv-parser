/// One LIMIT/OFFSET window. [fromDatabase] is false when the rows were sliced
/// from the JSON list already in memory, or when that list is not loaded.
class CatalogPage<T> {
  final List<T> rows;
  final int limit;
  final int offset;
  final bool fromDatabase;

  const CatalogPage({
    required this.rows,
    required this.limit,
    required this.offset,
    required this.fromDatabase,
  });
}
