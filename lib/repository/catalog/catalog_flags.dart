/// SQLite catalog reads stay off until a measured switch.
///
/// Shelves, search, and playback keep using the JSON files in `m3u_cache`.
/// An empty database does not change that path.
///
/// FTS5 is not used. sqflite on Android opens the device SQLite
/// (`android.database.sqlite.SQLiteDatabase`). This project cannot prove that
/// module is compiled into the Chromecast build, so lookup uses ordinary
/// indexes on kind, category, name, and item id.
///
/// Switch, after a device measurement, in this order:
/// 1. Ingest one kind with LocaleApi before that kind's JSON list is in
///    memory. The parse isolate inserts a batch, then drops it.
/// 2. Set [readsEnabled] to true.
/// 3. Point the shelf loader at the paged LocaleApi readers.
/// Until step 3, the full-list getters stay on JSON even if rows exist.
class CatalogDbFlags {
  static bool readsEnabled = false;

  /// Shelf pages stay small even if a caller asks for the whole catalog.
  static const int maxPage = 200;
}
