/// SQL shared by the device database and the unit-test executor.
///
/// No FTS5 virtual tables. Indexes are plain b-trees the device SQLite
/// already supports.
class CatalogSql {
  static const createItems = '''
CREATE TABLE catalog_items (
  kind TEXT NOT NULL,
  row_index INTEGER NOT NULL,
  name TEXT,
  item_id TEXT,
  category_id TEXT,
  payload TEXT NOT NULL,
  PRIMARY KEY (kind, row_index)
)''';

  static const createStaging = '''
CREATE TABLE catalog_items_staging (
  kind TEXT NOT NULL,
  row_index INTEGER NOT NULL,
  name TEXT,
  item_id TEXT,
  category_id TEXT,
  payload TEXT NOT NULL,
  PRIMARY KEY (kind, row_index)
)''';

  static const createMeta = '''
CREATE TABLE catalog_meta (
  kind TEXT PRIMARY KEY,
  ready INTEGER NOT NULL,
  row_count INTEGER NOT NULL
)''';

  static const indexCategory =
      'CREATE INDEX idx_catalog_items_cat ON catalog_items(kind, category_id, row_index)';

  static const indexName =
      'CREATE INDEX idx_catalog_items_name ON catalog_items(kind, name)';

  static const indexItem =
      'CREATE INDEX idx_catalog_items_item ON catalog_items(kind, item_id)';

  static const deleteStaging =
      'DELETE FROM catalog_items_staging WHERE kind = ?';

  static const deleteLive = 'DELETE FROM catalog_items WHERE kind = ?';

  static const copyStaging = '''
INSERT INTO catalog_items (kind, row_index, name, item_id, category_id, payload)
SELECT kind, row_index, name, item_id, category_id, payload
FROM catalog_items_staging
WHERE kind = ?''';

  static const upsertMeta =
      'INSERT OR REPLACE INTO catalog_meta (kind, ready, row_count) VALUES (?, ?, ?)';

  static const meta =
      'SELECT ready, row_count FROM catalog_meta WHERE kind = ?';

  static const page = '''
SELECT payload FROM catalog_items
WHERE kind = ?
ORDER BY row_index
LIMIT ? OFFSET ?''';

  static const pageByCategory = '''
SELECT payload FROM catalog_items
WHERE kind = ? AND category_id = ?
ORDER BY row_index
LIMIT ? OFFSET ?''';
}
