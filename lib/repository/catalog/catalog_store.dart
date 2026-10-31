import 'dart:convert';

import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import 'catalog_executor.dart';
import 'catalog_flags.dart';
import 'catalog_kind.dart';
import 'catalog_row_codec.dart';
import 'catalog_sql.dart';

/// Writes catalog batches and reads one page.
///
/// Live rows stay in place until [commitReplace]. A failed ingest calls
/// [abortReplace] and leaves the previous pageable rows alone.
class CatalogStore {
  CatalogStore(this._executor);

  final CatalogExecutor _executor;
  Future<void> _tail = Future<void>.value();

  Future<T> serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> beginReplace(CatalogKind kind) {
    return _executor.execute(CatalogSql.deleteStaging, [kind.storageKey]);
  }

  Future<void> addBatch(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return Future<void>.value();
    return _executor.insertRows('catalog_items_staging', rows);
  }

  Future<void> commitReplace(CatalogKind kind, int total) {
    final ready = total > 0 ? 1 : 0;
    return _executor.transaction([
      CatalogStatement(CatalogSql.deleteLive, [kind.storageKey]),
      CatalogStatement(CatalogSql.copyStaging, [kind.storageKey]),
      CatalogStatement(CatalogSql.deleteStaging, [kind.storageKey]),
      CatalogStatement(CatalogSql.upsertMeta, [kind.storageKey, ready, total]),
    ]);
  }

  Future<void> abortReplace(CatalogKind kind) {
    return _executor.execute(CatalogSql.deleteStaging, [kind.storageKey]);
  }

  Future<bool> isReady(CatalogKind kind) async {
    final rows = await _executor.query(CatalogSql.meta, [kind.storageKey]);
    if (rows.isEmpty) return false;
    final ready = rows.first['ready'];
    final count = rows.first['row_count'];
    final readyBit = ready is num ? ready.toInt() : 0;
    final rowCount = count is num ? count.toInt() : 0;
    return readyBit == 1 && rowCount > 0;
  }

  Future<List<ChannelSerie>> pageSeries({
    required int limit,
    required int offset,
    String? categoryId,
  }) {
    return serialize(
      () => _page(
        kind: CatalogKind.series,
        limit: limit,
        offset: offset,
        categoryId: categoryId,
        decode: CatalogRowCodec.decodeSeries,
      ),
    );
  }

  Future<List<ChannelMovie>> pageMovies({
    required int limit,
    required int offset,
    String? categoryId,
  }) {
    return serialize(
      () => _page(
        kind: CatalogKind.movie,
        limit: limit,
        offset: offset,
        categoryId: categoryId,
        decode: CatalogRowCodec.decodeMovie,
      ),
    );
  }

  Future<List<ChannelLive>> pageLive({
    required int limit,
    required int offset,
    String? categoryId,
  }) {
    return serialize(
      () => _page(
        kind: CatalogKind.live,
        limit: limit,
        offset: offset,
        categoryId: categoryId,
        decode: CatalogRowCodec.decodeLive,
      ),
    );
  }

  Future<void> close() => _executor.close();

  Future<List<T>> _page<T>({
    required CatalogKind kind,
    required int limit,
    required int offset,
    required String? categoryId,
    required T Function(Map<String, dynamic> json) decode,
  }) async {
    final safeLimit = _clampLimit(limit);
    final safeOffset = offset < 0 ? 0 : offset;
    if (safeLimit == 0) return <T>[];
    if (!await isReady(kind)) return <T>[];
    final filtered = categoryId != null && categoryId.isNotEmpty;
    final rows = await _executor.query(
      filtered ? CatalogSql.pageByCategory : CatalogSql.page,
      filtered
          ? [kind.storageKey, categoryId, safeLimit, safeOffset]
          : [kind.storageKey, safeLimit, safeOffset],
    );
    return [
      for (final row in rows)
        decode(
          Map<String, dynamic>.from(
            jsonDecode(row['payload']! as String) as Map,
          ),
        ),
    ];
  }

  static int _clampLimit(int limit) {
    if (limit <= 0) return 0;
    if (limit > CatalogDbFlags.maxPage) return CatalogDbFlags.maxPage;
    return limit;
  }
}
