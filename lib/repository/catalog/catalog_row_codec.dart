import 'dart:convert';

import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import 'catalog_kind.dart';
import 'catalog_string_pool.dart';

/// One indexed row. [payload] is the model JSON for that row only.
class CatalogRowCodec {
  static Map<String, Object?> encode(
    CatalogKind kind,
    int rowIndex,
    Map<String, dynamic> json,
    CatalogStringPool pool,
  ) {
    switch (kind) {
      case CatalogKind.series:
        return _series(rowIndex, json, pool);
      case CatalogKind.movie:
        return _movie(rowIndex, json, pool);
      case CatalogKind.live:
        return _live(rowIndex, json, pool);
    }
  }

  static ChannelSerie decodeSeries(Map<String, dynamic> json) =>
      ChannelSerie.fromJson(json);

  static ChannelMovie decodeMovie(Map<String, dynamic> json) =>
      ChannelMovie.fromJson(json);

  static ChannelLive decodeLive(Map<String, dynamic> json) =>
      ChannelLive.fromJson(json);

  static Map<String, Object?> _series(
    int rowIndex,
    Map<String, dynamic> json,
    CatalogStringPool pool,
  ) {
    final model = ChannelSerie.fromJson(json);
    final cover = pool.internNullable(model.cover);
    final categoryId = pool.internNullable(model.categoryId);
    final payload = ChannelSerie(
      num: model.num,
      name: model.name,
      seriesId: model.seriesId,
      cover: cover,
      plot: model.plot,
      rating: model.rating,
      rating5based: model.rating5based,
      categoryId: categoryId,
      directSource: model.directSource,
    ).toJson();
    return _row(
      CatalogKind.series,
      rowIndex,
      name: payload['name'] as String?,
      itemId: payload['series_id'] as String?,
      categoryId: payload['category_id'] as String?,
      payload: payload,
    );
  }

  static Map<String, Object?> _movie(
    int rowIndex,
    Map<String, dynamic> json,
    CatalogStringPool pool,
  ) {
    final model = ChannelMovie.fromJson(json);
    final icon = pool.internNullable(model.streamIcon);
    final categoryId = pool.internNullable(model.categoryId);
    final payload = ChannelMovie(
      num: model.num,
      name: model.name,
      streamType: model.streamType,
      streamId: model.streamId,
      streamIcon: icon,
      rating: model.rating,
      rating5based: model.rating5based,
      added: model.added,
      isAdult: model.isAdult,
      categoryId: categoryId,
      containerExtension: model.containerExtension,
      customSid: model.customSid,
      directSource: model.directSource,
      youtubeTrailer: model.youtubeTrailer,
      imdbId: model.imdbId,
    ).toJson();
    return _row(
      CatalogKind.movie,
      rowIndex,
      name: payload['name'] as String?,
      itemId: payload['stream_id'] as String?,
      categoryId: payload['category_id'] as String?,
      payload: payload,
    );
  }

  static Map<String, Object?> _live(
    int rowIndex,
    Map<String, dynamic> json,
    CatalogStringPool pool,
  ) {
    final model = ChannelLive.fromJson(json);
    final icon = pool.internNullable(model.streamIcon);
    final categoryId = pool.internNullable(model.categoryId);
    final payload = ChannelLive(
      num: model.num,
      name: model.name,
      streamType: model.streamType,
      streamId: model.streamId,
      streamIcon: icon,
      epgChannelId: model.epgChannelId,
      added: model.added,
      isAdult: model.isAdult,
      categoryId: categoryId,
      customSid: model.customSid,
      tvArchive: model.tvArchive,
      directSource: model.directSource,
      tvArchiveDuration: model.tvArchiveDuration,
    ).toJson();
    return _row(
      CatalogKind.live,
      rowIndex,
      name: payload['name'] as String?,
      itemId: payload['stream_id'] as String?,
      categoryId: payload['category_id'] as String?,
      payload: payload,
    );
  }

  static Map<String, Object?> _row(
    CatalogKind kind,
    int rowIndex, {
    required String? name,
    required String? itemId,
    required String? categoryId,
    required Map<String, dynamic> payload,
  }) {
    return {
      'kind': kind.storageKey,
      'row_index': rowIndex,
      'name': name,
      'item_id': itemId,
      'category_id': categoryId,
      'payload': jsonEncode(payload),
    };
  }
}
