import 'dart:async';

import 'package:android_tv_text_field/native_textfield_tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../helpers/helpers.dart';
import '../../../repository/api/ai_intent_mapper.dart';
import '../../../repository/api/api.dart';
import '../../../repository/api/search_index_service.dart';
import '../../../repository/api/user_behavior_service.dart';
import '../../../repository/models/category.dart';
import '../../../repository/models/channel_live.dart';
import '../../../repository/models/channel_movie.dart';
import '../../../repository/models/channel_serie.dart';
import '../../../repository/models/user_preference_profile.dart';
import '../../../repository/provider/title_normalizer.dart';
import '../screens/screens.dart';
import '../shared/widgets/stream_launcher.dart';
import 'widgets/tv_channel_grid.dart';

/// Android TV search destination backed by [SearchIndexService] + M3U/session catalog.
class TvSearchScreen extends StatefulWidget {
  final ValueChanged<String>? onChannelSelected;
  final bool embedded;

  const TvSearchScreen({
    super.key,
    this.onChannelSelected,
    this.embedded = false,
  });

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final NativeTextFieldController _searchController =
      NativeTextFieldController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'TvSearchField');
  Timer? _debounceTimer;

  List<ChannelLive> _allLiveChannels = [];
  List<ChannelMovie> _allMovies = [];
  List<ChannelSerie> _allSeries = [];
  Map<String, String> _categoryIdToName = {};

  List<ChannelLive> _liveResults = [];
  List<ChannelMovie> _movieResults = [];
  List<ChannelSerie> _seriesResults = [];

  bool _loading = false;
  bool _indexReady = false;
  bool _hasSearched = false;
  String _activeQuery = '';
  List<String> _recentSearches = [];

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

  /// Prefer session / LocaleApi cache (same source Live uses), then IpTvApi.
  Future<void> _loadCatalog() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // Sync readable lists first — Apollo/starlite M3U already in m3u_cache.
      var lives = IptvProviderSession.instance.liveChannels();
      var movies = IptvProviderSession.instance.movieChannels();
      var series = IptvProviderSession.instance.seriesChannels();

      if (lives.isEmpty && movies.isEmpty && series.isEmpty) {
        final api = IpTvApi();
        lives = await api.getLiveChannels("");
        movies = await api.getMovieChannels("");
        // Series after movies so Search can index movies first.
        series = await api.getSeriesChannels("");
      }

      final cats = <CategoryModel>[
        ...LocaleApi.getM3uCategories(),
        ...LocaleApi.getM3uMovieCategories(),
        ...LocaleApi.getM3uSeriesCategories(),
        ...IptvProviderSession.instance
            .categoriesForAction('get_live_categories'),
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
        _allSeries = series;
        _categoryIdToName = catMap;
      });

      debugPrint(
        '[TvSearch] catalog live=${lives.length} movies=${movies.length} '
        'series=${series.length} groups=${catMap.length} '
        'indexReady=${SearchIndexService.isReady} '
        'indexed=${SearchIndexService.totalIndexedEntries}',
      );

      await SearchIndexService.buildIndex(
        liveChannels: lives,
        movies: movies,
        series: series,
        adultCategoryIds: adultCategoryIds,
        categoryIdToName: catMap,
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _indexReady = SearchIndexService.isReady;
      });

      final pending = _searchController.text.trim();
      if (pending.isNotEmpty) {
        _performSearch(pending);
      }
    } catch (e) {
      debugPrint('TV search prefetch error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _indexReady = SearchIndexService.isReady;
        });
      }
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
      });
      return;
    }

    if (!SearchIndexService.isReady ||
        SearchIndexService.totalIndexedEntries == 0) {
      await SearchIndexService.buildIndex(
        liveChannels: _allLiveChannels,
        movies: _allMovies,
        series: _allSeries,
        categoryIdToName: _categoryIdToName,
      );
    }

    if (!mounted) return;

    final aiIntent = AiIntentMapper.parseQuery(clean);
    UserBehaviorService.trackSearch(clean);

    final searchResults = SearchIndexService.search(
      clean,
      expandedKeywords: aiIntent.keywords,
    );

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
      _seriesResults = series;
      _hasSearched = true;
      _activeQuery = clean;
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
        playerBuilder: () =>
            MoviePlayerScreen(link: url!, title: movie.name ?? 'Movie'),
      );
    }
  }

  void _openSeries(ChannelSerie serie) {
    UserBehaviorService.trackClick(serie.seriesId ?? '', serie.categoryId);
    Get.to(
      () => SerieContent(
        channelSerie: serie,
        videoId: serie.seriesId ?? '',
      ),
    );
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
        if (_loading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white24),
            ),
          )
        else
          Expanded(
            child: !_hasSearched
                ? _buildIdleState()
                : total == 0
                    ? _buildEmptyState()
                    : _buildResults(total),
          ),
      ],
    );

    if (widget.embedded) return body;

    return Shortcuts(
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
                            onTap: () => Get.back(),
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
                Expanded(child: body),
              ],
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
        if (!_indexReady && !_loading) ...[
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
    final rows = <TvChannelRow>[];
    const maxPerSection = 40;

    if (_liveResults.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: 'Live (${_liveResults.length})',
          streams: _liveResults.take(maxPerSection).map((ch) {
            return TvStreamRecord(
              title: ch.name ?? 'Live',
              subtitle: _groupFor(ch),
              streamUrl: ch.directSource ?? ch.streamId ?? '',
              imageUrl: ch.streamIcon,
              posterStyle: TvPosterStyle.liveLandscape,
            );
          }).toList(),
        ),
      );
    }
    if (_movieResults.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: 'Movies (${_movieResults.length})',
          streams: _movieResults.take(maxPerSection).map((m) {
            final parsed = TitleNormalizer.parse(m.name ?? '');
            return TvStreamRecord(
              title: parsed.displayTitle.isEmpty
                  ? (m.name ?? 'Movie')
                  : parsed.displayTitle,
              subtitle: parsed.year != null ? '${parsed.year}' : 'Movie',
              streamUrl: m.directSource ?? m.streamId ?? '',
              imageUrl: m.streamIcon,
              year: parsed.year,
              qualityLabel: parsed.qualityLabel,
              posterStyle: TvPosterStyle.vodPortrait,
              streamId: m.streamId,
              tvgId: m.imdbId,
              imdbId: m.imdbId,
              trailerUrl: m.youtubeTrailer,
            );
          }).toList(),
        ),
      );
    }
    if (_seriesResults.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: 'Series (${_seriesResults.length})',
          streams: _seriesResults.take(maxPerSection).map((s) {
            final parsed = TitleNormalizer.parse(s.name ?? '');
            return TvStreamRecord(
              title: parsed.displayTitle.isEmpty
                  ? (s.name ?? 'Series')
                  : parsed.displayTitle,
              subtitle: parsed.episodeBadge ?? 'Series',
              streamUrl: s.seriesId ?? '',
              imageUrl: s.cover,
              year: parsed.year,
              badge: parsed.episodeBadge,
              posterStyle: TvPosterStyle.vodPortrait,
            );
          }).toList(),
        ),
      );
    }

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
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: SizedBox(
                  height: row.streams.isNotEmpty && row.streams.first.isVod
                      ? 268
                      : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: row.streams.length,
                          itemBuilder: (context, i) {
                            final stream = row.streams[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 18),
                              child: TvChannelCard(
                                stream: stream,
                                onSelected: () {
                                  if (row.title.startsWith('Live')) {
                                    _playLive(_liveResults[i]);
                                  } else if (row.title.startsWith('Movies')) {
                                    _playMovie(_movieResults[i]);
                                  } else {
                                    _openSeries(_seriesResults[i]);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
