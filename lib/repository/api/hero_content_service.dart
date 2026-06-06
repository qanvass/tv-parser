import 'dart:developer';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'api.dart';
import 'trailer_lookup_service.dart';
import 'trailer_metadata_service.dart';
import '../cache/trailer_cache_service.dart';

enum HeroPreviewType {
  live,
  trailer,
  imageOnly,
}

class HeroCarouselItem {
  final String id;
  final String title;
  final String? cleanTitle;
  final String? year;
  final String? description;
  final String? streamUrl;
  final String? imageUrl;
  final String? trailerYoutubeId;
  final HeroPreviewType previewType;
  final bool isLive;
  final bool isVod;
  final ChannelMovie rawMovie;

  const HeroCarouselItem({
    required this.id,
    required this.title,
    this.cleanTitle,
    this.year,
    this.description,
    this.streamUrl,
    this.imageUrl,
    this.trailerYoutubeId,
    required this.previewType,
    required this.isLive,
    required this.isVod,
    required this.rawMovie,
  });

  bool get hasValidImage {
    return imageUrl != null && imageUrl!.trim().isNotEmpty;
  }

  bool get hasValidTrailer {
    return trailerYoutubeId != null && trailerYoutubeId!.trim().isNotEmpty;
  }

  bool get isHeroReady {
    final hasTitle = title.trim().isNotEmpty;

    if (previewType == HeroPreviewType.live) {
      return hasTitle && hasValidImage && isLive;
    }

    if (previewType == HeroPreviewType.trailer) {
      return hasTitle && hasValidImage && hasValidTrailer && isVod;
    }

    return hasTitle && hasValidImage;
  }
}

class HeroContentService {
  /// Asynchronously fetches details for candidates, normalizes metadata, cleans title noise,
  /// validates images and trailers, and returns a list of 8-12 prioritized HeroCarouselItems.
  static Future<List<HeroCarouselItem>> fetchAndEnrichHeroItems(
    List<ChannelMovie> rawHeroItems,
  ) async {
    final List<HeroCarouselItem> trailerReadyItems = [];
    final List<HeroCarouselItem> imageOnlyItems = [];
    final List<Future<void>> futures = [];

    for (final movie in rawHeroItems) {
      final streamIdStr = movie.streamId?.toString();
      if (streamIdStr == null || streamIdStr.isEmpty) continue;

      if (movie.customSid == 'live') {
        // Live items are processed directly without VOD detail network calls
        final item = HeroCarouselItem(
          id: streamIdStr,
          title: movie.name ?? 'Live Channel',
          imageUrl: movie.streamIcon,
          previewType: HeroPreviewType.live,
          isLive: true,
          isVod: false,
          rawMovie: movie,
        );
        if (item.hasValidImage) {
          trailerReadyItems.add(item);
          imageOnlyItems.add(item);
        }
        continue;
      }

      // VOD / Movie item - enrich asynchronously
      futures.add(() async {
        try {
          final detail = await IpTvApi.getMovieDetails(streamIdStr);
          if (detail != null) {
            final movieData = detail.movieData;
            final info = detail.info;

            final rawTitle = movieData?.name ?? movie.name ?? 'Featured Movie';
            final cleanTitle = TrailerMetadataService.cleanMovieTitle(rawTitle);
            final plot = info?.plot ?? '';
            final releaseDateStr = info?.releasedate ?? '';

            // Extract 4-digit year from release date
            String? year;
            if (releaseDateStr.isNotEmpty) {
              final match = RegExp(r'\b(202\d|199\d|201\d)\b').firstMatch(releaseDateStr);
              if (match != null) {
                year = match.group(0);
              }
            }

            // Artwork Strategy: backdrop path -> backdrop field -> movieImage -> streamIcon
            String? artworkUrl;
            if (info?.backdropPath != null && info!.backdropPath!.isNotEmpty) {
              artworkUrl = info.backdropPath!.first;
            } else if (info?.backdrop != null && info!.backdrop!.isNotEmpty) {
              artworkUrl = info.backdrop;
            } else if (info?.movieImage != null && info!.movieImage!.isNotEmpty) {
              artworkUrl = info.movieImage;
            } else {
              artworkUrl = movie.streamIcon;
            }

            // 1. Try Xtream metadata first
            var trailerId = TrailerLookupService.getYoutubeIdFromMetadata(detail);

            // 2. If missing, check local storage cache
            if (trailerId == null || trailerId.isEmpty) {
              final cached = TrailerCacheService.getEntry(cleanTitle, year);
              if (cached != null) {
                if (cached.failedLookup) {
                  log("[HERO_CONTENT_SERVICE] Trailer cache contains failed lookup for '$cleanTitle'. Skipping.");
                } else {
                  trailerId = cached.youtubeId;
                  log("[HERO_CONTENT_SERVICE] Trailer cache hit for '$cleanTitle': $trailerId");
                }
              }
            }

            final item = HeroCarouselItem(
              id: streamIdStr,
              title: rawTitle,
              cleanTitle: cleanTitle,
              year: year,
              description: plot,
              imageUrl: artworkUrl,
              trailerYoutubeId: trailerId,
              previewType: (trailerId != null && trailerId.isNotEmpty)
                  ? HeroPreviewType.trailer
                  : HeroPreviewType.imageOnly,
              isLive: false,
              isVod: true,
              rawMovie: movie,
            );

            if (item.hasValidImage) {
              if (item.hasValidTrailer) {
                trailerReadyItems.add(item);
              } else {
                imageOnlyItems.add(item);
              }
            }
          }
        } catch (e) {
          // Safe non-sensitive logs
          log("[HERO_CONTENT_SERVICE] Failed to fetch VOD details for stream ID $streamIdStr: $e");
        }
      }());
    }

    // Wait for all details to be fetched
    await Future.wait(futures);

    // Prioritize and Sort: 2026/2025 movies first
    int getYearPriority(String? year) {
      if (year == '2026') return 4;
      if (year == '2025') return 3;
      if (year == '2024') return 2;
      return 1;
    }

    final List<HeroCarouselItem> enrichedList = [];

    // 1. Live channel first (if any)
    final lives = trailerReadyItems.where((x) => x.isLive).toList();
    enrichedList.addAll(lives);

    // 2. VOD items (trailer-ready)
    final movies = trailerReadyItems.where((x) => x.isVod).toList();
    movies.sort((a, b) => getYearPriority(b.year).compareTo(getYearPriority(a.year)));
    enrichedList.addAll(movies);

    final trailerReadyVodCount = enrichedList.where((x) => x.isVod).length;

    if (trailerReadyVodCount >= 3) {
      log("[HERO_CONTENT_SERVICE] Enriched $trailerReadyVodCount trailer-ready VOD items. Returning trailer mode carousel.");
      return enrichedList.take(12).toList();
    } else {
      // Fallback rule: If fewer than 3 trailer-ready VOD items are found,
      // return safest available image-ready items instead, preserving trailers on matched items.
      log("[HERO_CONTENT_SERVICE] Only $trailerReadyVodCount trailer-ready VOD items found. Returning combined fallback list preserving trailers.");
      
      final List<HeroCarouselItem> fallbackList = [];
      
      // Combine all image-ready items from both lists (disjoint sets)
      final List<HeroCarouselItem> allImageReadyItems = [...trailerReadyItems, ...imageOnlyItems];
      
      // Deduplicate by stable ID
      final Map<String, HeroCarouselItem> uniqueItemsMap = {};
      for (final item in allImageReadyItems) {
        uniqueItemsMap[item.id] = item;
      }
      final allUniqueItems = uniqueItemsMap.values.toList();
      
      // Live channel
      final livesFallback = allUniqueItems.where((x) => x.isLive).toList();
      fallbackList.addAll(livesFallback);

      // VOD items sorted by year priority
      final moviesFallback = allUniqueItems.where((x) => x.isVod).toList();
      moviesFallback.sort((a, b) => getYearPriority(b.year).compareTo(getYearPriority(a.year)));
      fallbackList.addAll(moviesFallback);

      return fallbackList.take(12).toList();
    }
  }
}
