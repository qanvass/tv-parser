import 'dart:async';

import 'package:android_tv_text_field/native_textfield_tv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../helpers/helpers.dart';
import '../../../repository/api/ai_intent_mapper.dart';
import '../../../repository/api/api.dart';
import '../../../repository/api/artwork_url_resolver.dart';
import '../../../repository/api/search_index_service.dart';
import '../../../repository/api/user_behavior_service.dart';
import '../../../repository/models/category.dart';
import '../../../repository/models/channel_live.dart';
import '../../../repository/models/channel_movie.dart';
import '../../../repository/models/channel_serie.dart';
import '../../../repository/provider/series_collapse.dart';
import '../../../repository/models/user_preference_profile.dart';
import '../../../repository/provider/title_normalizer.dart';
import '../../../repository/provider/tmdb_enrichment_worker.dart';
import '../screens/screens.dart';
import '../shared/widgets/stream_launcher.dart';
import 'cinematic/cinematic_artwork.dart';
import 'cinematic/cinematic_title_placeholder.dart';
import 'cinematic/cinematic_tokens.dart';
import 'widgets/tv_artwork_shimmer.dart';
import 'widgets/tv_channel_grid.dart';

/// Android TV search destination backed by [SearchIndexService] + M3U/session catalog.
class TvSearchScreen extends StatefulWidget {
  final ValueChanged<String>? onChannelSelected;
  final bool embedded;
  final VoidCallback? onBackPressed;

  const TvSearchScreen({
    super.key,
    this.onChannelSelected,
    this.embedded = false,
    this.onBackPressed,
  });

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final NativeTextFieldController _searchController =
      NativeTextFieldController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'TvSearchField');
  Timer? _debounceTimer;
  int _searchSeq = 0;

  List<ChannelLive> _allLiveChannels = [];
  List<ChannelMovie> _allMovies = [];
  List<ChannelSerie> _allSeries = [];
  Map<String, String> _categoryIdToName = {};

  List<ChannelLive> _liveResults = [];
  List<ChannelMovie> _movieResults = [];
  List<ChannelSerie> _seriesResults = [];

  bool _indexReady = false;
  bool _hasSearched = false;
  String _activeQuery = '';
  List<String> _recentSearches = [];
  int _resultTab = 0;

  @override
  void initState() {
    super.initState();
    _fieldFocus.addListener(_onFieldFocusChange);
    _searchController.addListener(_onControllerTick);
    _recentSearches = UserPreferenceProfile.load().lastSearches;
    _loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFocus.requestFocus();
    });
  }

  void _onFieldFocusChange() {
    if (mounted) setState(() {});
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fieldFocus.removeListener(_onFieldFocusChange);
    _searchController.removeListener(_onControllerTick);
    _searchController.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  Map<String, String> _buildCategoryMap(List<CategoryModel> cats) {
    return {
      for (final cat in cats)
        if (cat.categoryId != null &&
            cat.categoryId!.isNotEmpty &&
            cat.categoryName != null &&
            cat.categoryName!.isNotEmpty)
          cat.categoryId!: cat.categoryName!,
    };
  }

  /// Session / LocaleApi cache only. Never cold-loads Series or buildIndex().
  Future<void> _loadCatalog() async {
    if (!mounted) return;
    try {
      // Live + Movies from whatever is already in session memory / file cache.
      // Do NOT call seriesChannels() or getSeriesChannels("") — that rematerializes
      // the full Series catalog. Series joins later via its existing index.
      var lives = IptvProviderSession.instance.liveChannels();
      var movies = IptvProviderSession.instance.movieChannels();

      final cats = <CategoryModel>[
        ...LocaleApi.getM3uCategories(),
        ...LocaleApi.getM3uMovieCategories(),
        ...LocaleApi.getM3uSeriesCategories(),
        ...IptvProviderSession.instance.categoriesForAction(
          'get_live_categories',
        ),
      ];
      final catMap = _buildCategoryMap(cats);

      final adultCategoryIds = <String>{};
      for (final cat in cats) {
        if (cat.categoryName != null &&
            ProviderCurationRules.isAdultCategory(cat.categoryName!)) {
          if (cat.categoryId != null) adultCategoryIds.add(cat.categoryId!);
        }
      }

      if (!mounted) return;
      setState(() {
        _allLiveChannels = lives;
        _allMovies = movies;
        _categoryIdToName = catMap;
        _indexReady = SearchIndexService.isReady;
      });

      debugPrint(
        '[TvSearch] catalog live=${lives.length} movies=${movies.length} '
        'seriesIndexed=${SearchIndexService.seriesIndexReady} '
        'groups=${catMap.length} '
        'indexReady=${SearchIndexService.isReady} '
        'indexed=${SearchIndexService.totalIndexedEntries}',
      );

      await _indexAvailableDomains(
        lives: lives,
        movies: movies,
        adultCategoryIds: adultCategoryIds,
        categoryIdToName: catMap,
      );

      if (lives.isEmpty) {
        try {
          final fetched = await IpTvApi().getLiveChannels("");
          if (!mounted) return;
          if (fetched.isNotEmpty) {
            setState(() => _allLiveChannels = fetched);
            await _indexAvailableDomains(
              lives: fetched,
              movies: const [],
              adultCategoryIds: adultCategoryIds,
              categoryIdToName: catMap,
            );
          }
        } catch (e) {
          debugPrint('TV search live fallback: $e');
        }
      }
    } catch (e) {
      debugPrint('TV search prefetch error: $e');
      if (mounted) {
        setState(() => _indexReady = SearchIndexService.isReady);
      }
    }
  }

  Future<void> _indexAvailableDomains({
    required List<ChannelLive> lives,
    required List<ChannelMovie> movies,
    required Set<String> adultCategoryIds,
    required Map<String, String> categoryIdToName,
  }) async {
    final jobs = <Future<void>>[];
    if (lives.isNotEmpty && !SearchIndexService.liveIndexReady) {
      jobs.add(
        SearchIndexService.indexLive(
          liveChannels: lives,
          adultCategoryIds: adultCategoryIds,
          categoryIdToName: categoryIdToName,
        ),
      );
    }
    if (movies.isNotEmpty && !SearchIndexService.moviesIndexReady) {
      jobs.add(
        SearchIndexService.indexMovies(
          movies: movies,
          adultCategoryIds: adultCategoryIds,
          categoryIdToName: categoryIdToName,
        ),
      );
    }
    if (SearchIndexService.seriesIndexReady == false && _allSeries.isNotEmpty) {
      jobs.add(
        SearchIndexService.indexSeries(
          series: _allSeries,
          adultCategoryIds: adultCategoryIds,
          categoryIdToName: categoryIdToName,
        ),
      );
    }
    if (jobs.isEmpty) {
      if (mounted) {
        setState(() => _indexReady = SearchIndexService.isReady);
      }
      return;
    }
    await Future.wait(jobs);
    if (!mounted) return;
    setState(() => _indexReady = SearchIndexService.isReady);
    final pending = _searchController.text.trim();
    if (pending.isNotEmpty) {
      await _performSearch(pending);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _liveResults = [];
        _movieResults = [];
        _seriesResults = [];
        _hasSearched = false;
        _activeQuery = '';
        _resultTab = 0;
      });
      return;
    }

    if (_allLiveChannels.isNotEmpty && !SearchIndexService.liveIndexReady) {
      unawaited(
        SearchIndexService.indexLive(
              liveChannels: _allLiveChannels,
              categoryIdToName: _categoryIdToName,
            )
            .then((_) {
              if (mounted && _searchController.text.trim() == clean) {
                _performSearch(clean);
              }
            })
            .catchError((Object e) {
              debugPrint('TV search live index: $e');
            }),
      );
    }
    if (_allMovies.isNotEmpty && !SearchIndexService.moviesIndexReady) {
      unawaited(
        SearchIndexService.indexMovies(
              movies: _allMovies,
              categoryIdToName: _categoryIdToName,
            )
            .then((_) {
              if (mounted && _searchController.text.trim() == clean) {
                _performSearch(clean);
              }
            })
            .catchError((Object e) {
              debugPrint('TV search movies index: $e');
            }),
      );
    }

    if (_allSeries.isNotEmpty && !SearchIndexService.seriesIndexReady) {
      unawaited(
        SearchIndexService.indexSeries(
              series: _allSeries,
              categoryIdToName: _categoryIdToName,
            )
            .then((_) {
              // indexSeries logs failures and returns normally; searching again
              // after one would start another build, in a loop.
              if (SearchIndexService.seriesIndexReady &&
                  mounted &&
                  _searchController.text.trim() == clean) {
                _performSearch(clean);
              }
            })
            .catchError((Object e) {
              debugPrint('TV search series index: $e');
            }),
      );
    }

    if (!mounted) return;

    final aiIntent = AiIntentMapper.parseQuery(clean);
    UserBehaviorService.trackSearch(clean);

    final searchSeq = ++_searchSeq;
    final searchResults = await SearchIndexService.searchAsync(
      clean,
      expandedKeywords: aiIntent.keywords,
      isStale: () => !mounted || searchSeq != _searchSeq,
    );
    if (searchResults == null || !mounted || searchSeq != _searchSeq) return;

    final lives = <ChannelLive>[];
    final movies = <ChannelMovie>[];
    final series = <ChannelSerie>[];

    for (final entry in searchResults) {
      if (entry.type == 'live') {
        lives.add(entry.item as ChannelLive);
      } else if (entry.type == 'movie') {
        movies.add(entry.item as ChannelMovie);
      } else {
        series.add(entry.item as ChannelSerie);
      }
    }

    setState(() {
      _liveResults = lives;
      _movieResults = movies;
      _seriesResults = SeriesCollapse.collapseByShow(series);
      _hasSearched = true;
      _activeQuery = clean;
      _resultTab = 0;
      _indexReady = SearchIndexService.isReady;
      _recentSearches = UserPreferenceProfile.load().lastSearches;
    });
  }

  void _applyQuery(String text) {
    _searchController.text = text;
    _onSearchChanged(text);
    _fieldFocus.requestFocus();
  }

  String _groupFor(ChannelLive ch) {
    final id = ch.categoryId;
    if (id == null || id.isEmpty) return 'Live';
    return _categoryIdToName[id] ?? 'Live';
  }

  Future<void> _playLive(ChannelLive channel) async {
    final url = await PlaybackUrlBuilder.resolveLivePlaybackUrl(channel);
    if (!mounted || url.isEmpty) return;
    UserBehaviorService.trackClick(channel.streamId ?? '', channel.categoryId);
    if (widget.onChannelSelected != null) {
      widget.onChannelSelected!(url);
    } else {
      StreamLauncher.openStreamWithBrandedLoading(
        context: context,
        streamUrl: url,
        playerBuilder: () => LivePlayerScreen(
          link: url,
          title: channel.name ?? 'Stream',
          streamId: channel.streamId,
        ),
      );
    }
  }

  Future<void> _playMovie(ChannelMovie movie) async {
    String? url;
    if (movie.directSource != null && movie.directSource!.isNotEmpty) {
      url = movie.directSource;
    } else if (movie.streamId != null) {
      url = await PlaybackUrlBuilder.buildMovieUrl(
        movie.streamId!,
        containerExtension: movie.containerExtension,
      );
    }
    if (!mounted || url == null || url.isEmpty) return;
    UserBehaviorService.trackClick(movie.streamId ?? '', movie.categoryId);
    if (widget.onChannelSelected != null) {
      widget.onChannelSelected!(url);
    } else {
      StreamLauncher.openStreamWithBrandedLoading(
        context: context,
        streamUrl: url,
        playerBuilder: () => MoviePlayerScreen(
          link: url!,
          title: movie.name ?? 'Movie',
          streamId: movie.streamId,
          image: movie.streamIcon,
          recordHistory: true,
        ),
      );
    }
  }

  void _openSeries(ChannelSerie serie) {
    UserBehaviorService.trackClick(serie.seriesId ?? '', serie.categoryId);
    Get.to(
      () => SerieContent(channelSerie: serie, videoId: serie.seriesId ?? ''),
    );
  }

  /// Same enrichment key / poster resolution as Movies rails — Search only.
  TvStreamRecord _movieSearchRecord(ChannelMovie m) {
    final poster = ArtworkUrlResolver.resolveVodPoster(
      streamIcon: m.streamIcon,
    );
    final parsed = TitleNormalizer.parse(m.name ?? '');
    final title = parsed.displayTitle.isEmpty
        ? (m.name ?? 'Movie')
        : parsed.displayTitle;
    final year = parsed.year;
    final key = TmdbEnrichmentWorker.cacheKeyFor(
      title,
      m.streamId,
      type: ContentType.movie,
      year: year,
      matchTitle: parsed.matchTitle,
    );
    return TvStreamRecord(
      title: title,
      subtitle: year != null ? '$year · Movie' : 'Movie',
      streamUrl: m.directSource ?? m.streamId ?? '',
      imageUrl: poster,
      backdropUrl: ArtworkUrlResolver.resolveHeroBackdrop(
        posterFallback: poster,
      ),
      year: year,
      qualityLabel: parsed.qualityLabel,
      posterStyle: TvPosterStyle.vodPortrait,
      streamId: m.streamId,
      tvgId: m.imdbId,
      imdbId: m.imdbId,
      trailerUrl: m.youtubeTrailer,
      enrichmentKey: key,
    );
  }

  TvStreamRecord _seriesSearchRecord(ChannelSerie s) {
    final poster = ArtworkUrlResolver.resolveVodPoster(cover: s.cover);
    final parsed = TitleNormalizer.parse(s.name ?? '');
    final title = parsed.displayTitle.isEmpty
        ? (s.name ?? 'Series')
        : parsed.displayTitle;
    final key = TmdbEnrichmentWorker.cacheKeyFor(
      title,
      s.seriesId,
      type: ContentType.series,
      year: parsed.year,
      matchTitle: parsed.matchTitle,
    );
    return TvStreamRecord(
      title: title,
      subtitle: parsed.year != null
          ? '${parsed.year} · Series'
          : (parsed.episodeBadge ?? 'Series'),
      streamUrl: s.directSource ?? s.seriesId ?? '',
      imageUrl: poster,
      backdropUrl: ArtworkUrlResolver.resolveHeroBackdrop(
        posterFallback: poster,
      ),
      year: parsed.year,
      qualityLabel: parsed.qualityLabel,
      badge: parsed.episodeBadge,
      season: parsed.season,
      episode: parsed.episode,
      overview: s.plot,
      posterStyle: TvPosterStyle.vodPortrait,
      streamId: s.seriesId,
      enrichmentKey: key,
    );
  }

  void _enqueueVisibleSearchTmdb({
    required List<TvStreamRecord> movies,
    required List<TvStreamRecord> series,
  }) {
    // ignore: unawaited_futures
    TmdbEnrichmentWorker.instance.ensureStarted();
    final reqs = <TmdbEnqueueRequest>[
      for (final s in movies)
        TmdbEnqueueRequest(
          rawTitle: s.title,
          providerId: s.streamId,
          type: ContentType.movie,
          posterUrl: s.imageUrl,
          backdropUrl: s.backdropUrl,
          trailerUrl: s.trailerUrl,
          year: s.year,
          imdbId: s.imdbId ?? s.tvgId,
        ),
      for (final s in series)
        TmdbEnqueueRequest(
          rawTitle: s.title,
          providerId: s.streamId,
          type: ContentType.series,
          posterUrl: s.imageUrl,
          backdropUrl: s.backdropUrl,
          overview: s.overview,
          year: s.year,
        ),
    ];
    if (reqs.isNotEmpty) {
      TmdbEnrichmentWorker.instance.enqueueMany(reqs);
    }
  }

  static int _vodColumnCount(double width) {
    if (width >= 900) return 5;
    if (width >= 680) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _liveResults.length + _movieResults.length + _seriesResults.length;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(),
        const SizedBox(height: 20),
        Expanded(
          child: !_hasSearched
              ? _buildIdleState()
              : total == 0
              ? _buildEmptyState()
              : _buildResults(total),
        ),
      ],
    );

    void triggerBack() {
      if (widget.onBackPressed != null) {
        widget.onBackPressed!();
      } else if (!widget.embedded) {
        Get.back();
      }
    }

    final searchWidget = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) triggerBack();
      },
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.goBack)) {
            triggerBack();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: body,
      ),
    );

    if (widget.embedded) return searchWidget;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) triggerBack();
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF050508),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Focus(
                        child: Builder(
                          builder: (context) {
                            final focused = Focus.of(context).hasFocus;
                            return InkWell(
                              onTap: triggerBack,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: focused
                                      ? Colors.white.withValues(alpha: 0.13)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: focused
                                        ? Colors.white
                                        : Colors.white24,
                                    width: focused ? 2 : 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: searchWidget),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final focused = _fieldFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? Colors.white : Colors.white24,
          width: focused ? 2.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: focused ? Colors.white : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: AndroidTVTextField(
                controller: _searchController,
                focusNode: _fieldFocus,
                hint: 'Search channels, movies, series…',
                height: 48,
                deferDpadToIme: true,
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                backgroundColor: Colors.transparent,
                textColor: Colors.white,
                focuesedBorderColor: Colors.transparent,
                unFocuesedBorderColor: Colors.transparent,
                textSize: 18,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Voice input uses the TV keyboard',
            onPressed: () => _fieldFocus.requestFocus(),
            icon: Icon(
              Icons.mic_none_rounded,
              color: focused ? kColorPrimary : Colors.white54,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
                _fieldFocus.requestFocus();
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    final recent = _recentSearches;
    final catalogHint = _allLiveChannels.isEmpty
        ? 'Load a playlist on Live first, then search here.'
        : 'Searching ${_allLiveChannels.length} live channels'
              '${_allMovies.isNotEmpty || _allSeries.isNotEmpty ? ', movies & series' : ''}.';

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (recent.isNotEmpty) ...[
          const Text(
            'Recent searches',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final q in recent.take(10))
                _RecentChip(label: q, onTap: () => _applyQuery(q)),
            ],
          ),
          const SizedBox(height: 28),
        ],
        Text(
          recent.isEmpty
              ? 'Start typing to search your playlist. Recent searches appear here.'
              : 'Select a recent query or type a new one.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          catalogHint,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 13,
          ),
        ),
        if (!_indexReady) ...[
          const SizedBox(height: 8),
          Text(
            'Index still building… results appear when ready.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No matches for “$_activeQuery”.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildResults(int total) {
    const maxPerSection = 40;

    final liveStreams = _liveResults.take(maxPerSection).map((ch) {
      return TvStreamRecord(
        title: ch.name ?? 'Live',
        subtitle: _groupFor(ch),
        streamUrl: ch.directSource ?? ch.streamId ?? '',
        imageUrl: ch.streamIcon,
        posterStyle: TvPosterStyle.liveLandscape,
      );
    }).toList();

    final movieStreams = _movieResults
        .take(maxPerSection)
        .map(_movieSearchRecord)
        .toList();
    final seriesStreams = _seriesResults
        .take(maxPerSection)
        .map(_seriesSearchRecord)
        .toList();

    // Only enrich what Search is about to show — never the whole catalog.
    _enqueueVisibleSearchTmdb(movies: movieStreams, series: seriesStreams);

    final rows = <TvChannelRow>[];
    if (liveStreams.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: 'Live (${_liveResults.length})',
          streams: liveStreams,
        ),
      );
    }
    if (movieStreams.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: 'Movies (${_movieResults.length})',
          streams: movieStreams,
        ),
      );
    }
    if (seriesStreams.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: 'Series (${_seriesResults.length})',
          streams: seriesStreams,
        ),
      );
    }

    final tabs = rows;
    if (tabs.isEmpty) return _buildEmptyState();
    final tab = _resultTab.clamp(0, tabs.length - 1);
    final row = tabs[tab];
    final isVod =
        row.streams.isNotEmpty &&
        row.streams.first.posterStyle == TvPosterStyle.vodPortrait;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$total results for “$_activeQuery”',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 220,
                child: ListView.separated(
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final on = index == tab;
                    return Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          setState(() => _resultTab = index);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(
                        builder: (context) {
                          final focused = Focus.of(context).hasFocus;
                          return GestureDetector(
                            onTap: () => setState(() => _resultTab = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: focused || on
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  width: focused ? 2 : 1,
                                  color: focused
                                      ? Colors.white
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(
                                tabs[index].title,
                                style: TextStyle(
                                  color: focused || on
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = isVod
                        ? _vodColumnCount(constraints.maxWidth)
                        : 4;
                    // Fixed row height for VOD: 210 poster + gap + 2-line title
                    // + optional year line + focus-scale breathing room.
                    final delegate = isVod
                        ? SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 258,
                          )
                        : SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.15,
                          );
                    return GridView.builder(
                      padding: const EdgeInsets.only(
                        right: 8,
                        bottom: 24,
                        top: 8,
                      ),
                      gridDelegate: delegate,
                      itemCount: row.streams.length,
                      itemBuilder: (context, i) {
                        final stream = row.streams[i];
                        final onSelected = () {
                          if (row.title.startsWith('Live')) {
                            _playLive(_liveResults[i]);
                          } else if (row.title.startsWith('Movies')) {
                            _playMovie(_movieResults[i]);
                          } else {
                            _openSeries(_seriesResults[i]);
                          }
                        };
                        if (stream.posterStyle == TvPosterStyle.vodPortrait) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: _SearchVodPosterCard(
                              stream: stream,
                              onSelected: onSelected,
                            ),
                          );
                        }
                        return TvChannelCard(
                          stream: stream,
                          onSelected: onSelected,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _RecentChip({required this.label, required this.onTap});

  @override
  State<_RecentChip> createState() => _RecentChipState();
}

class _RecentChipState extends State<_RecentChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: _focused
                    ? Colors.white.withValues(alpha: 0.14)
                    : const Color(0xFF16161C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _focused ? Colors.white : Colors.white24,
                  width: _focused ? 2 : 1,
                ),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _focused ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Search-only VOD card: real posters + 2-line titles outside the image.
/// Does not modify [CinematicPosterCard] (Movies stays frozen).
class _SearchVodPosterCard extends StatefulWidget {
  static const double posterW = 140;
  static const double posterH = 210;

  final TvStreamRecord stream;
  final VoidCallback onSelected;

  const _SearchVodPosterCard({required this.stream, required this.onSelected});

  @override
  State<_SearchVodPosterCard> createState() => _SearchVodPosterCardState();
}

class _SearchVodPosterCardState extends State<_SearchVodPosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Milder than Movies focus so scaled cards stay inside Search grid cells.
    const focusScale = 1.05;
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.gameButtonA ||
            k == LogicalKeyboardKey.space) {
          widget.onSelected();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? focusScale : 1.0,
        duration: CinematicMotion.focus,
        curve: CinematicMotion.standard,
        child: SizedBox(
          width: _SearchVodPosterCard.posterW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  canRequestFocus: false,
                  onTap: widget.onSelected,
                  borderRadius: BorderRadius.circular(
                    CinematicTokens.radiusPoster,
                  ),
                  child: AnimatedContainer(
                    duration: CinematicMotion.focus,
                    width: _SearchVodPosterCard.posterW,
                    height: _SearchVodPosterCard.posterH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        CinematicTokens.radiusPoster,
                      ),
                      border: Border.all(
                        width: _focused ? 1.4 : 0,
                        color: _focused
                            ? CinematicTokens.focus.withValues(alpha: 0.9)
                            : Colors.transparent,
                      ),
                      boxShadow: _focused
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListenableBuilder(
                      listenable: TmdbEnrichmentWorker.instance,
                      builder: (context, _) {
                        final extra = widget.stream.enrichmentKey == null
                            ? null
                            : TmdbEnrichmentWorker.instance.lookup(
                                widget.stream.enrichmentKey!,
                              );
                        final art = CinematicArtwork.fromRecord(
                          widget.stream,
                          extra: extra,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CinematicTitlePlaceholder(
                              title: widget.stream.title,
                            ),
                            if (ArtworkUrlResolver.isUsableImageUrl(art.poster))
                              Positioned.fill(
                                child: CachedNetworkImage(
                                  imageUrl: art.poster!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 320,
                                  fadeInDuration: CinematicMotion.backdrop,
                                  httpHeaders: ArtworkUrlResolver.imageHeaders,
                                  placeholder: (_, _) =>
                                      const TvArtworkShimmer(),
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.expand(),
                                ),
                              ),
                            if (_focused)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x18FFFFFF),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.stream.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _focused
                      ? CinematicTokens.textPrimary
                      : CinematicTokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (widget.stream.subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.stream.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
