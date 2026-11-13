import 'package:flutter/material.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../shared/favorite_actions.dart';
import 'widgets/tv_channel_grid.dart';

Object favoriteItemForRecord(TvStreamRecord record) {
  final subtitleLower = record.subtitle.toLowerCase();
  final enrichmentLower = record.enrichmentKey?.toLowerCase() ?? '';
  final series = record.isSeries ||
      record.groupedEpisodes.isNotEmpty ||
      record.lazyEpisodeCount > 0 ||
      record.season != null ||
      record.episode != null ||
      enrichmentLower.startsWith('series') ||
      enrichmentLower.contains('series|') ||
      enrichmentLower.contains(':series:') ||
      subtitleLower == 'series' ||
      subtitleLower.contains('series') ||
      subtitleLower.contains('episode');
  // Grouped show cards keep an episode id so the existing series resolver
  // can recover all seasons. Never save a display title as a provider id.
  final anchor = record.groupedEpisodes.isEmpty
      ? record
      : record.groupedEpisodes.first;
  final id = anchor.streamId?.isNotEmpty == true
      ? anchor.streamId
      : anchor.streamUrl;
  final url = Uri.tryParse(anchor.streamUrl);
  final direct = url != null && (url.scheme == 'http' || url.scheme == 'https')
      ? anchor.streamUrl
      : null;
  if (series) {
    return ChannelSerie(
      seriesId: id,
      name: record.title,
      cover: record.imageUrl,
      directSource: direct,
      categoryId: record.providerCategoryId,
      plot: record.overview,
    );
  }
  if (record.isVod) {
    return ChannelMovie(streamId: id, name: record.title,
        streamIcon: record.imageUrl, directSource: direct,
        categoryId: record.providerCategoryId);
  }
  return ChannelLive(streamId: id, name: record.title,
      streamIcon: record.imageUrl, directSource: direct,
      categoryId: record.providerCategoryId, epgChannelId: record.tvgId);
}

Future<void> addRecordToFavorites(BuildContext context, TvStreamRecord record) =>
    FavoriteActions.add(context, favoriteItemForRecord(record));
