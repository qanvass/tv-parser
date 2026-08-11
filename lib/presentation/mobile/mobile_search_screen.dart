import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

import '../../logic/blocs/auth/auth_bloc.dart';
import '../../logic/cubits/favorites/favorites_cubit.dart';
import '../../repository/api/api.dart';
import '../../repository/api/search_index_service.dart';
import '../../repository/api/ai_intent_mapper.dart';
import '../../repository/api/user_behavior_service.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/ranked_item.dart';
import '../screens/screens.dart';
import 'widgets/horizontal_poster_rows.dart';
import 'mobile_detail_screen.dart';
import '../shared/widgets/stream_launcher.dart';

class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({super.key});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<ChannelLive> _allLiveChannels = [];
  List<ChannelMovie> _allMovies = [];
  List<ChannelSerie> _allSeries = [];

  List<RankedItem<dynamic>> _topResults = [];
  List<ChannelLive> _filteredLiveResults = [];
  List<ChannelMovie> _filteredMovieResults = [];
  List<ChannelSerie> _filteredSeriesResults = [];

  bool _loading = false;
  bool _hasSearched = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllCatalogData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Prefetches all playlist items into local memory so searching is instant
  Future<void> _loadAllCatalogData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final api = IpTvApi();

      final lives = await api.getLiveChannels("");
      final movies = await api.getMovieChannels("");
      if (mounted) {
        setState(() {
          _allLiveChannels = lives;
          _allMovies = movies;
        });
        await SearchIndexService.indexMovies(movies: movies);
      }
      final series = await api.getSeriesChannels("");

      if (mounted) {
        setState(() {
          _allSeries = series;
          _loading = false;
        });

        // Build the search index with the newly fetched data
        await SearchIndexService.buildIndex(
          liveChannels: _allLiveChannels,
          movies: _allMovies,
          series: _allSeries,
        );

        // If the user already started typing while fetching was in progress,
        // perform the search again now that the catalog index is ready.
        if (_searchController.text.trim().isNotEmpty) {
          _performSearch(_searchController.text);
        }
      }
    } catch (e) {
      debugPrint("Search prefetch error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (!mounted) return;
    if (query.trim().isEmpty) {
      setState(() {
        _topResults = [];
        _filteredLiveResults = [];
        _filteredMovieResults = [];
        _filteredSeriesResults = [];
        _hasSearched = false;
        _activeQuery = '';
      });
      return;
    }

    final queryClean = query.trim();

    // Ensure search index is built/ready
    if (!SearchIndexService.isReady) {
      SearchIndexService.buildIndex(
        liveChannels: _allLiveChannels,
        movies: _allMovies,
        series: _allSeries,
      );
    }

    // AI Intent Mapping keyword expansion
    final aiIntent = AiIntentMapper.parseQuery(queryClean);

    // Track search behavior in learning loop
    UserBehaviorService.trackSearch(queryClean);

    // Look up in our fast non-blocking search index using the original query as primary
    // and expanded intent keywords as secondary to prevent global search from being restricted.
    final searchResults = SearchIndexService.search(
      queryClean,
      expandedKeywords: aiIntent.keywords,
    );

    final List<ChannelLive> liveResults = [];
    final List<ChannelMovie> movieResults = [];
    final List<ChannelSerie> seriesResults = [];
    final List<RankedItem<dynamic>> topMatches = [];

    for (var i = 0; i < searchResults.length; i++) {
      final entry = searchResults[i];
      final isLive = entry.type == 'live';
      final isMovie = entry.type == 'movie';

      if (isLive) {
        liveResults.add(entry.item as ChannelLive);
      } else if (isMovie) {
        movieResults.add(entry.item as ChannelMovie);
      } else {
        seriesResults.add(entry.item as ChannelSerie);
      }

      // Convert top results to RankedItems
      if (topMatches.length < 5) {
        topMatches.add(
          RankedItem(
            item: entry.item,
            score: 100.0 - i, // Artificial score from search index rank
            confidence: isLive ? 0.95 : (isMovie ? 0.90 : 0.88),
            reasons: ["Search Index Match"],
            contentType: entry.type,
            sourceRow: 'search_results',
          ),
        );
      }
    }

    setState(() {
      _topResults = topMatches;
      _filteredLiveResults = liveResults;
      _filteredMovieResults = movieResults;
      _filteredSeriesResults = seriesResults;
      _hasSearched = true;
      _activeQuery = query;
    });
  }

  void _applyQuickQuery(String text) {
    _searchController.text = text;
    _onSearchChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final totalResults =
        _filteredLiveResults.length +
        _filteredMovieResults.length +
        _filteredSeriesResults.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Search Input Panel
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Get.back(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Colors.white.withOpacity(0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Search channels, movies, series...",
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                ),
              )
            else
              Expanded(
                child: BlocBuilder<FavoritesCubit, FavoritesState>(
                  builder: (context, favState) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_hasSearched) _buildQuickSearchTags(),

                          if (_hasSearched && totalResults == 0)
                            _buildEmptyState()
                          else if (_hasSearched)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    "Found $totalResults results for \"$_activeQuery\"",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Top Results (Premium group)
                                if (_topResults.isNotEmpty)
                                  HorizontalPosterRows(
                                    title: "Top Match Recommendations",
                                    titleIcon: Icons.workspace_premium_rounded,
                                    titleIconColor: Colors.amber,
                                    itemCount: _topResults.length,
                                    aspect: PosterAspect.landscape,
                                    itemBuilder: (context, index) {
                                      final rItem = _topResults[index];
                                      final item = rItem.item;
                                      final bool isLive =
                                          rItem.contentType == 'live';
                                      final bool isMovie =
                                          rItem.contentType == 'movie';
                                      final String title =
                                          RankedItem.getItemTitle(item);
                                      final String? imageUrl = isLive
                                          ? item.streamIcon
                                          : item.streamIcon;

                                      final bool isFav = isLive
                                          ? favState.lives.any(
                                              (l) =>
                                                  l.streamId == item.streamId,
                                            )
                                          : isMovie
                                          ? favState.movies.any(
                                              (m) =>
                                                  m.streamId == item.streamId,
                                            )
                                          : favState.series.any(
                                              (s) =>
                                                  s.seriesId == item.seriesId,
                                            );

                                      return PosterCard(
                                        title: title,
                                        imageUrl: imageUrl,
                                        aspect: PosterAspect.landscape,
                                        isLive: isLive,
                                        isFavorite: isFav,
                                        ratingBadge:
                                            "Score: ${rItem.score.toInt()}",
                                        onLongPress: () {
                                          if (isLive) {
                                            context
                                                .read<FavoritesCubit>()
                                                .addLive(item, isAdd: !isFav);
                                          } else if (isMovie) {
                                            context
                                                .read<FavoritesCubit>()
                                                .addMovie(item, isAdd: !isFav);
                                          } else {
                                            context
                                                .read<FavoritesCubit>()
                                                .addSerie(item, isAdd: !isFav);
                                          }
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isFav
                                                    ? "Removed from Favourites"
                                                    : "Added to Favourites",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.amber.shade900,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        },
                                        onTap: () {
                                          UserBehaviorService.trackClick(
                                            item.streamId ?? '',
                                            item.categoryId,
                                          );
                                          if (isLive) {
                                            _onLiveChannelTap(item);
                                          } else if (isMovie) {
                                            _showMovieDetailSheet(item);
                                          } else {
                                            Get.to(
                                              () => SerieContent(
                                                channelSerie: item,
                                                videoId: item.seriesId ?? '',
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),

                                // Live Results
                                if (_filteredLiveResults.isNotEmpty)
                                  HorizontalPosterRows(
                                    title:
                                        "Live TV Matches (${_filteredLiveResults.length})",
                                    titleIcon: Icons.live_tv_rounded,
                                    titleIconColor: const Color(0xFFFFC107),
                                    itemCount: _filteredLiveResults.length,
                                    aspect: PosterAspect.landscape,
                                    itemBuilder: (context, index) {
                                      final ch = _filteredLiveResults[index];
                                      final isFav = favState.lives.any(
                                        (l) => l.streamId == ch.streamId,
                                      );
                                      return PosterCard(
                                        title: ch.name ?? 'Live Stream',
                                        imageUrl: ch.streamIcon,
                                        aspect: PosterAspect.landscape,
                                        isLive: true,
                                        isFavorite: isFav,
                                        onLongPress: () {
                                          context
                                              .read<FavoritesCubit>()
                                              .addLive(ch, isAdd: !isFav);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isFav
                                                    ? "Removed from Favourites"
                                                    : "Added to Favourites",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.amber.shade900,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        },
                                        onTap: () {
                                          UserBehaviorService.trackClick(
                                            ch.streamId ?? '',
                                            ch.categoryId,
                                          );
                                          _onLiveChannelTap(ch);
                                        },
                                      );
                                    },
                                  ),

                                // Movie Results
                                if (_filteredMovieResults.isNotEmpty)
                                  HorizontalPosterRows(
                                    title:
                                        "Movies Matches (${_filteredMovieResults.length})",
                                    titleIcon: Icons.movie_rounded,
                                    titleIconColor: const Color(0xFFFF416C),
                                    itemCount: _filteredMovieResults.length,
                                    aspect: PosterAspect.vertical,
                                    itemBuilder: (context, index) {
                                      final movie =
                                          _filteredMovieResults[index];
                                      final isFav = favState.movies.any(
                                        (m) => m.streamId == movie.streamId,
                                      );
                                      return PosterCard(
                                        title: movie.name ?? 'Movie VOD',
                                        imageUrl: movie.streamIcon,
                                        aspect: PosterAspect.vertical,
                                        isFavorite: isFav,
                                        ratingBadge: movie.rating != null
                                            ? "⭐ ${movie.rating}"
                                            : null,
                                        onLongPress: () {
                                          context
                                              .read<FavoritesCubit>()
                                              .addMovie(movie, isAdd: !isFav);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isFav
                                                    ? "Removed from Favourites"
                                                    : "Added to Favourites",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.amber.shade900,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        },
                                        onTap: () {
                                          UserBehaviorService.trackClick(
                                            movie.streamId ?? '',
                                            movie.categoryId,
                                          );
                                          _showMovieDetailSheet(movie);
                                        },
                                      );
                                    },
                                  ),

                                // Series Results
                                if (_filteredSeriesResults.isNotEmpty)
                                  HorizontalPosterRows(
                                    title:
                                        "Series Matches (${_filteredSeriesResults.length})",
                                    titleIcon: Icons.tv_rounded,
                                    titleIconColor: const Color(0xFF00C6FF),
                                    itemCount: _filteredSeriesResults.length,
                                    aspect: PosterAspect.vertical,
                                    itemBuilder: (context, index) {
                                      final serie =
                                          _filteredSeriesResults[index];
                                      final isFav = favState.series.any(
                                        (s) => s.seriesId == serie.seriesId,
                                      );
                                      return PosterCard(
                                        title: serie.name ?? 'Series',
                                        imageUrl: serie.cover,
                                        aspect: PosterAspect.vertical,
                                        isFavorite: isFav,
                                        ratingBadge: serie.rating != null
                                            ? "⭐ ${serie.rating}"
                                            : null,
                                        onLongPress: () {
                                          context
                                              .read<FavoritesCubit>()
                                              .addSerie(serie, isAdd: !isFav);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isFav
                                                    ? "Removed from Favourites"
                                                    : "Added to Favourites",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.amber.shade900,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        },
                                        onTap: () {
                                          UserBehaviorService.trackClick(
                                            serie.seriesId ?? '',
                                            serie.categoryId,
                                          );
                                          Get.to(
                                            () => SerieContent(
                                              channelSerie: serie,
                                              videoId: serie.seriesId ?? '',
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchTags() {
    final tags = [
      "news",
      "local channels",
      "live sports",
      "documentaries",
      "Spanish movies",
      "kids cartoons",
      "action movies",
      "comedy series",
      "music channels",
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recommended Searches",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: tags
                .map(
                  (t) => GestureDetector(
                    onTap: () => _applyQuickQuery(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            const Text(
              "No results found",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We couldn't find matches for \"$_activeQuery\". Try checking the spelling or using broader search terms.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onLiveChannelTap(ChannelLive channel) async {
    final streamUrl = await PlaybackUrlBuilder.resolveLivePlaybackUrl(channel);
    if (streamUrl.isEmpty || !mounted) return;
    StreamLauncher.openStreamWithBrandedLoading(
      context: context,
      streamUrl: streamUrl,
      playerBuilder: () => LivePlayerScreen(
        link: streamUrl,
        title: channel.name ?? 'Stream',
        streamIcon: channel.streamIcon,
        streamId: channel.streamId,
      ),
    );
  }

  void _onMoviePlayTap(ChannelMovie movie) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      final user = authState.user;
      final streamUrl =
          "${user.serverInfo?.serverUrl}/movie/${user.userInfo?.username}/${user.userInfo?.password}/${movie.streamId}.${movie.containerExtension ?? 'mp4'}";
      StreamLauncher.openStreamWithBrandedLoading(
        context: context,
        streamUrl: streamUrl,
        playerBuilder: () =>
            MoviePlayerScreen(link: streamUrl, title: movie.name ?? 'Stream'),
      );
    }
  }

  void _showMovieDetailSheet(ChannelMovie movie) {
    Get.to(
      () => MobileDetailScreen(
        movie: movie,
        onPlayTap: () {
          Get.back();
          _onMoviePlayTap(movie);
        },
      ),
    );
  }
}
