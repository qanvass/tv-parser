import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import '../../logic/blocs/categories/live_caty/live_caty_bloc.dart';
import '../../logic/blocs/categories/movie_caty/movie_caty_bloc.dart';
import '../../logic/blocs/categories/series_caty/series_caty_bloc.dart';
import '../../logic/cubits/favorites/favorites_cubit.dart';
import '../../repository/api/api.dart';
import '../../repository/api/content_intelligence_service.dart';
import '../../repository/api/search_index_service.dart';
import '../../repository/api/ai_intent_mapper.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/category.dart';
import '../screens/screens.dart';
import '../../helpers/helpers.dart';
import 'widgets/horizontal_poster_rows.dart';
import 'widgets/live_category_chips.dart';
import 'mobile_detail_screen.dart';
import '../widgets/premium_channel_card.dart';
import '../shared/widgets/stream_launcher.dart';

enum BrowseMode { live, movies, series, countries, languages, categories }

class AllContentScreen extends StatefulWidget {
  final BrowseMode initialMode;
  const AllContentScreen({super.key, required this.initialMode});

  @override
  State<AllContentScreen> createState() => _AllContentScreenState();
}

class _AllContentScreenState extends State<AllContentScreen> {
  late BrowseMode _currentMode;

  List<CategoryModel> _liveCategories = [];
  List<CategoryModel> _movieCategories = [];
  List<CategoryModel> _seriesCategories = [];

  List<dynamic> _loadedStreams = [];
  CategoryModel? _selectedCategory;
  bool _loading = false;

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _loadCategories();

    // Ensure search index is ready for fast global lookups
    if (!SearchIndexService.isReady) {
      _buildSearchIndex();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buildSearchIndex() async {
    try {
      final api = IpTvApi();
      final lives = await api.getLiveChannels("");
      final movies = await api.getMovieChannels("");
      await SearchIndexService.indexMovies(movies: movies);
      final series = await api.getSeriesChannels("");
      await SearchIndexService.buildIndex(
        liveChannels: lives,
        movies: movies,
        series: series,
      );
    } catch (_) {}
  }

  void _loadCategories() {
    final liveState = context.read<LiveCatyBloc>().state;
    if (liveState is LiveCatySuccess) _liveCategories = liveState.categories;

    final movieState = context.read<MovieCatyBloc>().state;
    if (movieState is MovieCatySuccess)
      _movieCategories = movieState.categories;

    final seriesState = context.read<SeriesCatyBloc>().state;
    if (seriesState is SeriesCatySuccess)
      _seriesCategories = seriesState.categories;

    _autoSelectFirstCategory();
  }

  void _autoSelectFirstCategory() {
    final list = _getCategoryFilterList();
    if (list.isNotEmpty) {
      _onCategorySelected(list.first);
    }
  }

  void _onCategorySelected(CategoryModel category) async {
    setState(() {
      _selectedCategory = category;
      _loadedStreams = [];
      _loading = true;
    });

    try {
      final api = IpTvApi();
      if (_currentMode == BrowseMode.live ||
          _currentMode == BrowseMode.countries ||
          _currentMode == BrowseMode.languages) {
        final data = await api.getLiveChannels(category.categoryId ?? '');
        final filtered = data
            .where(
              (item) => ContentIntelligenceService.isLiveChannel(
                item,
                categoryName: category.categoryName,
              ),
            )
            .toList();
        final deduped = ContentIntelligenceService.deduplicate<ChannelLive>(
          filtered,
          (c) => c.name ?? c.streamId ?? '',
        );
        if (mounted) setState(() => _loadedStreams = deduped);
      } else if (_currentMode == BrowseMode.movies) {
        final data = await api.getMovieChannels(category.categoryId ?? '');
        final filtered = data
            .where(
              (item) => ContentIntelligenceService.isMovieVOD(
                item,
                categoryName: category.categoryName,
              ),
            )
            .toList();
        final deduped = ContentIntelligenceService.deduplicate<ChannelMovie>(
          filtered,
          (c) => c.name ?? c.streamId ?? '',
        );
        if (mounted) setState(() => _loadedStreams = deduped);
      } else if (_currentMode == BrowseMode.series) {
        final data = await api.getSeriesChannels(category.categoryId ?? '');
        final filtered = data
            .where((item) => ContentIntelligenceService.isSeriesVOD(item))
            .toList();
        final deduped = ContentIntelligenceService.deduplicate<ChannelSerie>(
          filtered,
          (c) => c.name ?? c.seriesId ?? '',
        );
        if (mounted) setState(() => _loadedStreams = deduped);
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  List<CategoryModel> _getCategoryFilterList() {
    if (_currentMode == BrowseMode.movies) return _movieCategories;
    if (_currentMode == BrowseMode.series) return _seriesCategories;

    if (_currentMode == BrowseMode.countries) {
      return _liveCategories.where((c) {
        final name = (c.categoryName ?? '').toLowerCase();
        return name.contains('usa') ||
            name.contains('uk') ||
            name.contains('canada') ||
            name.contains('spain') ||
            name.contains('mexico') ||
            name.contains('france') ||
            name.contains('germany') ||
            name.contains('italy') ||
            name.contains('latino');
      }).toList();
    }

    if (_currentMode == BrowseMode.languages) {
      return _liveCategories.where((c) {
        final name = (c.categoryName ?? '').toLowerCase();
        return name.contains('english') ||
            name.contains('spanish') ||
            name.contains('french') ||
            name.contains('arabic') ||
            name.contains('portuguese') ||
            name.contains('hindi');
      }).toList();
    }

    return _liveCategories;
  }

  // Fast AI global search logic
  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  void _performSearch(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      _searchQuery = clean;
    });

    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final stopwatch = Stopwatch()..start();

    // Natural language expansion using AiIntentMapper
    final intent = AiIntentMapper.parseQuery(clean);
    final results = SearchIndexService.search(
      clean,
      expandedKeywords: intent.keywords,
    );

    final filtered = results
        .where((entry) {
          if (_currentMode == BrowseMode.live ||
              _currentMode == BrowseMode.countries ||
              _currentMode == BrowseMode.languages) {
            return entry.type == 'live';
          } else if (_currentMode == BrowseMode.movies) {
            return entry.type == 'movie';
          } else if (_currentMode == BrowseMode.series) {
            return entry.type == 'series';
          }
          return false;
        })
        .map((entry) => entry.item)
        .toList();

    stopwatch.stop();

    if (kDebugMode) {
      debugPrint(
        '[AllLiveSearch] query="$query" results=${filtered.length} durationMs=${stopwatch.elapsedMilliseconds}',
      );
    }

    setState(() {
      _searchResults = filtered;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searchQuery.isNotEmpty) {
          _searchController.clear();
          _onSearchChanged('');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F10),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final isWide = constraints.maxWidth >= 600;
            final useLandscape =
                (isWide || isLandscape) &&
                (isTvDevice() || OrientationGuard.allowMobileLandscape);

            if (useLandscape) {
              return _buildLandscapeLayout(context, constraints);
            } else {
              return _buildPortraitLayout(context, constraints);
            }
          },
        ),
      ),
    );
  }

  // 1. Portrait Layout
  Widget _buildPortraitLayout(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final categories = _getCategoryFilterList();
    final isLive =
        _currentMode == BrowseMode.live ||
        _currentMode == BrowseMode.countries ||
        _currentMode == BrowseMode.languages;
    final displayStreams = _searchQuery.isNotEmpty
        ? _searchResults
        : _loadedStreams;

    // Dynamic columns count based on portrait size constraints
    final int cols = constraints.maxWidth > 360 ? 3 : 2;

    if (kDebugMode) {
      debugPrint(
        '[AllLiveScreen] platform=android_mobile layout=portrait columns=$cols category="${_selectedCategory?.categoryName ?? ""}"',
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          _buildHeaderBar(),

          // AI Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: _buildSearchBar(),
          ),
          const SizedBox(height: 8),

          // Horizontal Categories chips (Only visible when not searching)
          if (_searchQuery.isEmpty && categories.isNotEmpty)
            LiveCategoryChips(
              categories: categories,
              selectedCategoryId: _selectedCategory?.categoryId ?? '',
              onCategorySelected: (cat) => _onCategorySelected(cat),
            ),

          // Main Grid Area
          Expanded(
            child: _loading || _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                  )
                : displayStreams.isEmpty
                ? _buildEmptyState()
                : _buildGrid(displayStreams, cols, isLive),
          ),
        ],
      ),
    );
  }

  // 2. Landscape Layout
  Widget _buildLandscapeLayout(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final categories = _getCategoryFilterList();
    final isLive =
        _currentMode == BrowseMode.live ||
        _currentMode == BrowseMode.countries ||
        _currentMode == BrowseMode.languages;
    final displayStreams = _searchQuery.isNotEmpty
        ? _searchResults
        : _loadedStreams;

    // Dynamic math sizing for widescreen
    final int cols = ((constraints.maxWidth - 240) ~/ 130).clamp(4, 6);

    if (kDebugMode) {
      debugPrint(
        '[AllLiveScreen] platform=android_mobile layout=landscape columns=$cols category="${_selectedCategory?.categoryName ?? ""}"',
      );
    }

    return Row(
      children: [
        // Left Vertical Rail (Width: 240px)
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF131314),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.04),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => Get.back(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Categories",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected =
                        cat.categoryId == _selectedCategory?.categoryId;
                    return _CategoryFocusableTap(
                      autofocus: index == 0,
                      onActivate: () => _onCategorySelected(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.04)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Text(
                          cat.categoryName ?? 'Category',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right Content Area (Widescreen layout)
        Expanded(
          child: SafeArea(
            left: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Right top content row (title + search bar)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getTitleText(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${_loadedStreams.length} items from your source",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          _buildRotationQuickButton(),
                        ],
                      ),
                      SizedBox(width: 280, child: _buildSearchBar()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Results Header (Only when searching)
                  if (_searchQuery.isNotEmpty) ...[
                    Text(
                      "Search Results (${displayStreams.length} found)",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Landscape Grid View
                  Expanded(
                    child: _loading || _isSearching
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFC107),
                            ),
                          )
                        : displayStreams.isEmpty
                        ? _buildEmptyState()
                        : _buildGrid(displayStreams, cols, isLive),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Header widgets
  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 6),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitleText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${_loadedStreams.length} items from your source",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _buildRotationQuickButton(),
        ],
      ),
    );
  }

  Widget _buildRotationQuickButton() {
    if (isTvDevice()) return const SizedBox.shrink();
    final allowed = OrientationGuard.allowMobileLandscape;
    return IconButton(
      icon: Icon(
        allowed
            ? Icons.screen_lock_portrait_rounded
            : Icons.screen_rotation_rounded,
        color: allowed ? const Color(0xFFFFC107) : Colors.white60,
        size: 20,
      ),
      tooltip: allowed ? "Disable Landscape Mode" : "Enable Landscape Mode",
      onPressed: () => _showRotationConfirmationDialog(context),
    );
  }

  void _showRotationConfirmationDialog(BuildContext context) {
    final allowed = OrientationGuard.allowMobileLandscape;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        title: Text(
          allowed ? "Lock Screen to Portrait?" : "Allow Landscape Rotation?",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          allowed
              ? "Screen will be locked to portrait mode during browsing."
              : "Browsing screens will automatically rotate to landscape when you tilt your device.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await OrientationGuard.setAllowLandscape(!allowed);
              setState(() {});
            },
            child: Text(allowed ? "Lock Portrait" : "Allow Landscape"),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.0),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: "Search channels, movies, series, or categories...",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.4),
            size: 18,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: Colors.white60,
                    size: 16,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildGrid(List<dynamic> list, int cols, bool isLive) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favState) {
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12.0),
          cacheExtent: 400.0,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: isLive ? 1.15 : 0.72,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            String title = '';
            String? coverUrl;

            if (item is ChannelLive) {
              title = item.name ?? '';
              coverUrl = item.streamIcon;
            } else if (item is ChannelMovie) {
              title = item.name ?? '';
              coverUrl = item.streamIcon;
            } else if (item is ChannelSerie) {
              title = item.name ?? '';
              coverUrl = item.cover;
            }

            final isFav = _isItemFavorite(item, favState);

            if (isLive) {
              // Redesigned premium card for live channels
              return PremiumChannelCard(
                title: title,
                imageUrl: coverUrl,
                isLive: true,
                isFavorite: isFav,
                onLongPress: () => _toggleItemFavorite(item, isFav),
                onTap: () => _onItemTapped(item),
              );
            }

            // Fallback to standard vertical posters for movies/series VOD
            return PosterCard(
              title: title,
              imageUrl: coverUrl,
              aspect: PosterAspect.vertical,
              isFavorite: isFav,
              onLongPress: () => _toggleItemFavorite(item, isFav),
              onTap: () => _onItemTapped(item),
            );
          },
        );
      },
    );
  }

  String _getTitleText() {
    switch (_currentMode) {
      case BrowseMode.live:
        return "All Live Channels";
      case BrowseMode.movies:
        return "All Movies VOD";
      case BrowseMode.series:
        return "All Series & Shows";
      case BrowseMode.countries:
        return "Browse by Country";
      case BrowseMode.languages:
        return "Browse by Language";
      case BrowseMode.categories:
        return "Browse Categories";
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_rounded,
            size: 48,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? "No matching channels found"
                : "No content available",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Try a title, channel name, genre, or category",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Clear Search"),
            ),
          ],
        ],
      ),
    );
  }

  void _onItemTapped(dynamic item) {
    if (item is ChannelLive) {
      _playLive(item);
    } else if (item is ChannelMovie) {
      _showMovieDetailSheet(item);
    } else if (item is ChannelSerie) {
      Get.to(
        () => SerieContent(channelSerie: item, videoId: item.seriesId ?? ''),
      );
    }
  }

  void _playLive(ChannelLive channel) async {
    if (channel.directSource != null && channel.directSource!.isNotEmpty) {
      final streamUrl = channel.directSource!;
      StreamLauncher.openStreamWithBrandedLoading(
        context: context,
        streamUrl: streamUrl,
        playerBuilder: () =>
            MoviePlayerScreen(link: streamUrl, title: channel.name ?? 'Stream'),
      );
    } else if (channel.streamId != null) {
      final streamUrl = await PlaybackUrlBuilder.buildLiveUrl(
        channel.streamId!,
      );
      if (streamUrl.isNotEmpty) {
        StreamLauncher.openStreamWithBrandedLoading(
          context: context,
          streamUrl: streamUrl,
          playerBuilder: () => MoviePlayerScreen(
            link: streamUrl,
            title: channel.name ?? 'Stream',
          ),
        );
      }
    }
  }

  void _onMoviePlayTap(ChannelMovie movie) async {
    if (movie.streamId != null) {
      final streamUrl = await PlaybackUrlBuilder.buildMovieUrl(
        movie.streamId!,
        containerExtension: movie.containerExtension,
      );
      if (streamUrl.isNotEmpty) {
        StreamLauncher.openStreamWithBrandedLoading(
          context: context,
          streamUrl: streamUrl,
          playerBuilder: () =>
              MoviePlayerScreen(link: streamUrl, title: movie.name ?? 'Stream'),
        );
      }
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

  bool _isItemFavorite(dynamic item, FavoritesState favState) {
    if (item is ChannelLive) {
      return favState.lives.any((l) => l.streamId == item.streamId);
    } else if (item is ChannelMovie) {
      return favState.movies.any((m) => m.streamId == item.streamId);
    } else if (item is ChannelSerie) {
      return favState.series.any((s) => s.seriesId == item.seriesId);
    }
    return false;
  }

  void _toggleItemFavorite(dynamic item, bool isFav) {
    if (item is ChannelLive) {
      context.read<FavoritesCubit>().addLive(item, isAdd: !isFav);
    } else if (item is ChannelMovie) {
      context.read<FavoritesCubit>().addMovie(item, isAdd: !isFav);
    } else if (item is ChannelSerie) {
      context.read<FavoritesCubit>().addSerie(item, isAdd: !isFav);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFav ? "Removed from Favourites" : "Added to Favourites",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Wraps a category row item so it's reachable and activatable via
/// D-pad/remote (Select/Enter/Space) in addition to touch.
class _CategoryFocusableTap extends StatefulWidget {
  const _CategoryFocusableTap({
    required this.onActivate,
    required this.child,
    this.autofocus = false,
  });

  final VoidCallback onActivate;
  final Widget child;
  final bool autofocus;

  @override
  State<_CategoryFocusableTap> createState() => _CategoryFocusableTapState();
}

class _CategoryFocusableTapState extends State<_CategoryFocusableTap> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          widget.onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onActivate,
        child: Container(
          decoration: _focused
              ? BoxDecoration(border: Border.all(color: Colors.white, width: 2))
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
