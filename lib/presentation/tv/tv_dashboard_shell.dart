import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../helpers/helpers.dart';
import '../../logic/blocs/auth/auth_bloc.dart';
import '../../logic/blocs/categories/live_caty/live_caty_bloc.dart';
import '../../logic/blocs/categories/movie_caty/movie_caty_bloc.dart';
import '../../logic/blocs/categories/series_caty/series_caty_bloc.dart';
import '../../repository/api/api.dart';
import '../../repository/api/content_intelligence_service.dart';
import '../../repository/models/category.dart';
import '../../repository/models/user_preference_profile.dart';
import 'widgets/tv_channel_grid.dart';
import 'widgets/tv_navigation_rail.dart';
import 'widgets/tv_live_spotlight_row.dart';
import 'widgets/tv_local_tv_row.dart';
import '../../repository/api/event_discovery_service.dart';
import '../../repository/api/artwork_url_resolver.dart';
import '../../repository/api/catalog_perf.dart';
import '../../repository/api/category_presentation_mapper.dart';
import '../../repository/api/search_index_service.dart';
import '../../repository/api/local_market_service.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/spotlight_event.dart';
import '../../repository/models/premium_plus_item.dart';
import '../../repository/api/premium_plus_service.dart';
import '../../repository/provider/provider_enums.dart';
import '../../repository/provider/title_normalizer.dart';
import '../../repository/provider/tmdb_enrichment_worker.dart';
import '../../logic/cubits/watch/watching_cubit.dart';
import 'series_rail_grouper.dart';
import 'widgets/tv_live_category_chips.dart';
import 'widgets/tv_premium_plus_row.dart';
import 'widgets/tv_home_rows.dart';
import 'widgets/tv_shell_backdrop.dart';
import 'widgets/tv_status_clock.dart';
import 'tv_search_screen.dart';
import 'cinematic/cinematic_movies_page.dart';
import 'live/live_hero_preview_controller.dart';
import 'live/live_preview_trace.dart';
import 'live/live_browse_gate.dart';

/// Primary rail destinations (content panes). Favorites/History deep-link out.
class _TvNav {
  static const live = 0;
  static const movies = 1;
  static const series = 2;
  static const search = 3;
  static const favorites = 4;
  static const history = 5;
}

class TvDashboardShell extends StatefulWidget {
  final ValueChanged<String> onChannelSelected;

  const TvDashboardShell({super.key, required this.onChannelSelected});

  @override
  State<TvDashboardShell> createState() => _TvDashboardShellState();
}

class _TvDashboardShellState extends State<TvDashboardShell>
    with WidgetsBindingObserver {
  int _selectedNavIndex = _TvNav.live;
  bool _loading = false;
  bool _isMoviesRefreshing = false;
  bool _isSeriesRefreshing = false;
  DateTime? _moviesRailStartedAt;
  DateTime? _seriesRailStartedAt;
  bool _railCollapsed = false;

  static const int _primaryCount = 6;

  final List<FocusNode> _navFocusNodes = List.generate(
    _primaryCount,
    (i) => FocusNode(debugLabel: 'TvNavPrimary$i'),
  );
  final List<FocusNode> _utilityFocusNodes = [
    FocusNode(debugLabel: 'TvNavSettings'),
  ];
  final FocusNode _retryFocus = FocusNode(debugLabel: 'TvContentRetry');

  late final List<TvNavigationItem> _navItems;
  late final List<TvNavigationItem> _utilityItems;

  List<TvChannelRow> _liveRows = [];
  List<TvChannelRow> _movieRows = [];
  List<TvChannelRow> _seriesRows = [];
  TvStreamRecord? _focusedVodStream;
  int _liveGroupCount = 0;
  List<SpotlightEvent> _tvSpotlightEvents = [];
  List<ChannelLive> _tvAllLiveChannels = [];
  List<PremiumPlusItem> _tvPremiumPlusItems = [];
  TvStreamRecord? _focusedLiveStream;
  late final LiveHeroPreviewController _livePreview;
  String? _liveCategoryFilter;
  String? _movieCategoryFilter;
  String? _seriesCategoryFilter;

  @override
  void initState() {
    super.initState();
    _livePreview = LiveHeroPreviewController();
    WidgetsBinding.instance.addObserver(this);

    _navItems = const [
      TvNavigationItem(label: 'Live TV', icon: Icons.live_tv_rounded),
      TvNavigationItem(label: 'Movies', icon: Icons.local_movies_rounded),
      TvNavigationItem(label: 'Series', icon: Icons.tv_rounded),
      TvNavigationItem(label: 'Search', icon: Icons.search_rounded),
      TvNavigationItem(label: 'Favorites', icon: Icons.favorite_rounded),
      TvNavigationItem(label: 'History', icon: Icons.history_rounded),
    ];
    _utilityItems = const [
      TvNavigationItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        isUtility: true,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navFocusNodes.isNotEmpty) {
        _navFocusNodes.first.requestFocus();
      }
      _loadRealPlaylistContent();
      // XMLTV after first frame — never block Live rails.
      XmlTvRepository.instance.ensureLoaded(
        playlistUrl: IptvProviderSession.instance.playlistUrl,
      );
    });
    XmlTvRepository.instance.addListener(_onXmlTvReady);
    IptvProviderSession.instance.onMoviesCatalogReady = _onMoviesCatalogReady;
    IptvProviderSession.instance.onSeriesCatalogReady = _onSeriesCatalogReady;
    FocusManager.instance.addListener(_syncRailCollapse);
  }

  bool get _liveSurfaceVisible {
    if (!mounted || _selectedNavIndex != _TvNav.live) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  void _onLiveChannelFocused(TvStreamRecord stream) {
    if (!mounted) return;
    final eligible = LiveHeroPreviewPolicy.isLivePreviewSource(stream);
    final raw = stream.streamUrl.trim();
    LivePreviewTrace.log(
      'focused_record_selected',
      'channel=${stream.title} hasStreamUrl=${raw.isNotEmpty} '
      'hash=${LivePreviewTrace.urlHash(raw)} '
      'isVod=${stream.isVod} eligible=$eligible '
      'liveVisible=$_liveSurfaceVisible '
      'looksHttp=${raw.startsWith('http')} len=${raw.length}',
    );
    if (!eligible) return;
    setState(() => _focusedLiveStream = stream);
    if (_liveSurfaceVisible) {
      // Never start VLC under the Welcome Hold card — play() can block the
      // UI thread and freeze that overlay on Chromecast.
      LiveBrowseGate.whenBrowseReady(() {
        if (!mounted || !_liveSurfaceVisible) return;
        if (_focusedLiveStream?.streamUrl != stream.streamUrl) return;
        _livePreview.request(stream);
      });
    }
  }

  void _syncLivePreview({bool immediate = false}) {
    if (!_liveSurfaceVisible) {
      LivePreviewTrace.log(
        'sync_skipped',
        'reason=live_not_visible nav=$_selectedNavIndex',
      );
      return;
    }
    final stream = _focusedLiveStream;
    if (stream == null) {
      LivePreviewTrace.log('sync_skipped', 'reason=no_focused_stream');
      return;
    }
    LivePreviewTrace.log(
      'focused_record_selected',
      'channel=${stream.title} hasStreamUrl=${stream.streamUrl.trim().isNotEmpty} '
      'hash=${LivePreviewTrace.urlHash(stream.streamUrl)} '
      'immediate=$immediate source=sync',
    );
    LiveBrowseGate.whenBrowseReady(() {
      if (!mounted || !_liveSurfaceVisible) return;
      if (_focusedLiveStream?.streamUrl != stream.streamUrl) return;
      _livePreview.request(stream, immediate: immediate);
      unawaited(_livePreview.forceMuted());
    });
  }

  /// Explicit Watch Live / Live card handoff.
  /// Captures this record, releases preview, then plays THIS streamUrl.
  Future<void> _watchLive(TvStreamRecord active) async {
    final url = active.streamUrl;
    final heroHash = _livePreview.activeUrlHash;
    final watchHash = LivePreviewTrace.urlHash(url);
    LivePreviewTrace.log(
      'watch_live_handoff',
      'channel=${active.title} heroHash=$heroHash watchHash=$watchHash '
      'match=${heroHash == watchHash} hasStreamUrl=${url.trim().isNotEmpty}',
    );
    await _livePreview.stopAndRelease(reason: 'fullscreen_handoff');
    if (!mounted) return;
    widget.onChannelSelected(url);
    unawaited(_resumePreviewWhenDashboardCurrent());
  }

  /// URL-only Live launches (home/local rows that already hold streamUrl).
  Future<void> _openPlayback(String streamUrl) async {
    final heroHash = _livePreview.activeUrlHash;
    final watchHash = LivePreviewTrace.urlHash(streamUrl);
    LivePreviewTrace.log(
      'watch_live_handoff',
      'source=url_only heroHash=$heroHash watchHash=$watchHash '
      'match=${heroHash == watchHash}',
    );
    await _livePreview.stopAndRelease(reason: 'fullscreen_handoff');
    if (!mounted) return;
    widget.onChannelSelected(streamUrl);
    unawaited(_resumePreviewWhenDashboardCurrent());
  }

  /// Live → Movies: drop the hero provider slot before the Movies pane appears.
  Future<void> _leaveLiveForMovies() async {
    // ignore: avoid_print
    print('[PLAYBACK_HANDOFF] preview_release_requested reason=live_to_movies');
    await _livePreview.stopAndRelease(reason: 'live_to_movies');
    // ignore: avoid_print
    print(
      '[PLAYBACK_HANDOFF] preview_release_completed reason=live_to_movies '
      'phase=${_livePreview.phase.name}',
    );
    if (!mounted) return;
    setState(() {
      _selectedNavIndex = _TvNav.movies;
      _railCollapsed = false;
    });
  }

  /// Cinematic Movies play only. Await existing preview release, then
  /// the existing Welcome movie route. Does not resume Live hero.
  Future<void> _openMovieFromCatalog(String streamUrl) async {
    // ignore: avoid_print
    print('[PLAYBACK_HANDOFF] preview_release_requested reason=movie_play');
    await _livePreview.stopAndRelease(reason: 'movie_play');
    if (!mounted) return;
    // ignore: avoid_print
    print(
      '[PLAYBACK_HANDOFF] preview_release_completed reason=movie_play '
      'phase=${_livePreview.phase.name}',
    );
    // ignore: avoid_print
    print(
      '[PLAYBACK_HANDOFF] movie_open_requested '
      'hash=${LivePreviewTrace.urlHash(streamUrl)}',
    );
    widget.onChannelSelected(streamUrl);
  }

  Future<void> _resumePreviewWhenDashboardCurrent() async {
    final route = ModalRoute.of(context);
    if (route == null) return;
    var covered = false;
    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      if (!route.isCurrent) {
        covered = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!covered) return;
    while (mounted && !route.isCurrent) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    _syncLivePreview(immediate: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LivePreviewTrace.log(
      'app_lifecycle',
      'state=${state.name} liveVisible=$_liveSurfaceVisible '
      'hash=${_livePreview.activeUrlHash}',
    );
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_livePreview.release(reason: 'lifecycle'));
      case AppLifecycleState.resumed:
        if (_liveSurfaceVisible) {
          _syncLivePreview(immediate: true);
        }
    }
  }

  void _loadRealPlaylistContent() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _liveRows = [];
        _isMoviesRefreshing = true;
        _isSeriesRefreshing = true;
        _moviesRailStartedAt = DateTime.now();
        _seriesRailStartedAt = DateTime.now();
        CatalogPerf.anchor('movie_rail');
        CatalogPerf.anchor('series_rail');
        CatalogPerf.timeline('MOVIES_START');
        CatalogPerf.timeline('SERIES_START');
        // FIX 3: keep last-known-good movie (and series) rows while refreshing.
        _liveGroupCount = 0;
      });
    }

    final liveCatyState = context.read<LiveCatyBloc>().state;
    final movieCatyState = context.read<MovieCatyBloc>().state;
    final seriesCatyState = context.read<SeriesCatyBloc>().state;

    // M3U login often arrives before GetLiveCategories finishes — wait briefly.
    var liveCats = liveCatyState is LiveCatySuccess
        ? liveCatyState.categories
        : <CategoryModel>[];
    if (liveCats.isEmpty) {
      for (var i = 0; i < 25 && mounted; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        final s = context.read<LiveCatyBloc>().state;
        if (s is LiveCatySuccess) {
          liveCats = s.categories;
          break;
        }
      }
      if (liveCats.isEmpty && mounted) {
        context.read<LiveCatyBloc>().add(GetLiveCategories());
        for (var i = 0; i < 25 && mounted; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
          final s = context.read<LiveCatyBloc>().state;
          if (s is LiveCatySuccess) {
            liveCats = s.categories;
            break;
          }
        }
      }
    }

    // M3U: if LiveCaty race/empty, read file/memory cache directly.
    if (liveCats.isEmpty) {
      liveCats = LocaleApi.getM3uCategories();
    }

    var movieCats = movieCatyState is MovieCatySuccess
        ? movieCatyState.categories
        : <CategoryModel>[];
    var seriesCats = seriesCatyState is SeriesCatySuccess
        ? seriesCatyState.categories
        : <CategoryModel>[];

    final profile = UserPreferenceProfile.load();
    final api = IpTvApi();
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) {
      if (mounted) setState(() {
        _loading = false;
        _isMoviesRefreshing = false;
        _isSeriesRefreshing = false;
      });
      return;
    }

    List<ChannelLive> allLives = [];
    List<SpotlightEvent> spots = [];

    try {
      // Live-only on the critical path so splash -> shell is interactive ASAP.
      allLives = await api.getLiveChannels("");

      // Prefer durable group-title categories; never collapse to a fake "Live".
      if (liveCats.isEmpty && allLives.isNotEmpty) {
        final cached = LocaleApi.getM3uCategories();
        if (cached.isNotEmpty) {
          liveCats = cached;
        } else {
          final seen = <String>{};
          liveCats = [];
          for (final ch in allLives) {
            final id = ch.categoryId;
            if (id == null || id.isEmpty || seen.contains(id)) continue;
            seen.add(id);
            liveCats.add(
              CategoryModel(
                categoryId: id,
                categoryName: id,
                parentId: '0',
              ),
            );
          }
        }
      }

      spots = await EventDiscoveryService.getSpotlightEvents(
        region: profile.region,
      );
    } catch (_) {}

    final Map<String, String> liveCategoryIdToName = {
      for (final cat in liveCats)
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!,
    };

    final premiumPlusItems = PremiumPlusService.matchPremiumPlusChannels(
      allLives,
      categoryIdToName: liveCategoryIdToName,
      forceRefresh: true,
    );

    if (mounted) {
      setState(() {
        _tvAllLiveChannels = allLives;
        _tvSpotlightEvents = spots;
        _tvPremiumPlusItems = premiumPlusItems;
        final cachedGroups = LocaleApi.getM3uCategories();
        _liveGroupCount = cachedGroups.isNotEmpty
            ? cachedGroups.length
            : (liveCats.isNotEmpty ? liveCats.length : 0);
      });
    }

    if (liveCats.isNotEmpty) {
      final categories = liveCats;
      final normalCats = categories
          .where(
            (c) =>
                c.categoryName != null &&
                !ProviderCurationRules.isAdultCategory(c.categoryName!),
          )
          .toList();
      final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(
        normalCats,
      );

      final byCat = <String, List<ChannelLive>>{};
      for (final ch in allLives) {
        final id = ch.categoryId;
        if (id == null || id.isEmpty) continue;
        byCat.putIfAbsent(id, () => []).add(ch);
      }

      final List<TvChannelRow> rows = [];
      for (final cat in sortedCats) {
        final catId = cat.categoryId;
        if (catId == null) continue;
        try {
          final chs = byCat[catId] ?? const <ChannelLive>[];
          if (chs.isEmpty) continue;
          final sortedChs = ContentIntelligenceService.sortLives(
            chs,
            profile,
            categories,
          );
          final List<TvStreamRecord> records = [];
          for (var i = 0; i < sortedChs.length; i++) {
            final ch = sortedChs[i];
            String streamUrl = '';
            if (ch.directSource != null && ch.directSource!.isNotEmpty) {
              streamUrl = ch.directSource!;
            } else if (ch.streamId != null) {
              streamUrl = ch.streamId!;
            }
            final logo = ArtworkUrlResolver.resolveLiveLogo(
              primaryUrl: ch.streamIcon,
              epgOrTvgId: ch.epgChannelId?.toString(),
            ) ?? '';
            final name = ch.name ?? 'Live Stream';
            records.add(
              TvStreamRecord(
                title: name,
                subtitle: cat.categoryName ?? 'Live',
                streamUrl: streamUrl,
                imageUrl: logo.isEmpty ? null : logo,
                isHd: _looksHd(name),
                tvgId: ch.epgChannelId?.toString(),
                streamId: ch.streamId,
              ),
            );
          }
          if (records.isNotEmpty) {
            rows.add(
              TvChannelRow(
                title: cat.categoryName ?? 'Live TV',
                streams: records,
              ),
            );
          }
        } catch (_) {}
      }

      final usedIds = sortedCats.map((c) => c.categoryId).whereType<String>().toSet();
      for (final entry in byCat.entries) {
        if (usedIds.contains(entry.key)) continue;
        final name = liveCategoryIdToName[entry.key] ?? 'More Live';
        if (ProviderCurationRules.isAdultCategory(name)) continue;
        final records = <TvStreamRecord>[];
        for (var i = 0; i < entry.value.length; i++) {
          final ch = entry.value[i];
          final logo = ArtworkUrlResolver.resolveLiveLogo(
            primaryUrl: ch.streamIcon,
            epgOrTvgId: ch.epgChannelId?.toString(),
          ) ?? '';
          final chName = ch.name ?? 'Live Stream';
          records.add(
            TvStreamRecord(
              title: chName,
              subtitle: name,
              streamUrl: (ch.directSource?.isNotEmpty == true)
                  ? ch.directSource!
                  : (ch.streamId ?? ''),
              imageUrl: logo.isEmpty ? null : logo,
              isHd: _looksHd(chName),
              tvgId: ch.epgChannelId?.toString(),
              streamId: ch.streamId,
            ),
          );
        }
        if (records.isNotEmpty) {
          rows.add(TvChannelRow(title: name, streams: records));
        }
      }

      if (mounted) {
        setState(() {
          _liveRows = rows;
          if (_focusedLiveStream == null &&
              rows.isNotEmpty &&
              rows.first.streams.isNotEmpty) {
            _focusedLiveStream = rows.first.streams.first;
          }
          // Live shell interactive — do not wait on Movies/Series rails.
          _loading = false;
        });
        _syncLivePreview(immediate: true);
        CatalogPerf.mark('firstLiveMs');
        CatalogPerf.mark('app_shell_ms');
        CatalogPerf.count('liveRowsPublished', rows.length);
        CatalogPerf.count('liveCount', allLives.length);
        CatalogPerf.count('liveGroups', _liveGroupCount);
        CatalogPerf.flush('first_live_ui');
      }
    } else if (allLives.isNotEmpty && mounted) {
      final records = <TvStreamRecord>[];
      for (var i = 0; i < allLives.length; i++) {
        final ch = allLives[i];
        final logo = ArtworkUrlResolver.resolveLiveLogo(
          primaryUrl: ch.streamIcon,
          epgOrTvgId: ch.epgChannelId?.toString(),
        ) ?? '';
        final chName = ch.name ?? 'Live Stream';
        records.add(
          TvStreamRecord(
            title: chName,
            subtitle: 'Live',
            streamUrl: (ch.directSource?.isNotEmpty == true)
                ? ch.directSource!
                : (ch.streamId ?? ''),
            imageUrl: logo.isEmpty ? null : logo,
            isHd: _looksHd(chName),
            tvgId: ch.epgChannelId?.toString(),
            streamId: ch.streamId,
          ),
        );
      }
      setState(() {
        _liveRows = [TvChannelRow(title: 'All Live', streams: records)];
        _focusedLiveStream ??= records.isNotEmpty ? records.first : null;
        _loading = false;
      });
      _syncLivePreview(immediate: true);
      CatalogPerf.mark('firstLiveMs');
      CatalogPerf.mark('app_shell_ms');
      CatalogPerf.count('liveRowsPublished', 1);
      CatalogPerf.count('liveCount', allLives.length);
      CatalogPerf.flush('first_live_ui');
    } else if (mounted) {
      setState(() => _loading = false);
    }

    // Independent Movies / Series pipelines — neither waits on the other.
    // ignore: unawaited_futures
    _loadMovieRails(
      api: api,
      profile: profile,
      allLives: allLives,
      movieCats: movieCats,
    );
    // ignore: unawaited_futures
    _loadSeriesRails(
      api: api,
      profile: profile,
      seriesCats: seriesCats,
    );
  }

  Future<void> _loadMovieRails({
    required IpTvApi api,
    required UserPreferenceProfile profile,
    required List<ChannelLive> allLives,
    required List<CategoryModel> movieCats,
  }) async {
    CatalogPerf.timeline('MOVIES_START');
    await LocaleApi.warmM3uMovieCache();
    CatalogPerf.timeline('MOVIES_CACHE_READY');
    if (!mounted) return;

    if (movieCats.isEmpty) {
      // Prefer persisted VOD cats over login-time MovieCatySuccess([]).
      movieCats = LocaleApi.getM3uMovieCategories();
      if (movieCats.isEmpty) {
        final s = context.read<MovieCatyBloc>().state;
        if (s is MovieCatySuccess && s.categories.isNotEmpty) {
          movieCats = s.categories;
        }
      }
      if (movieCats.isNotEmpty) {
        context.read<MovieCatyBloc>().add(HydrateMovieCategories(movieCats));
      }
    }

    List<ChannelMovie> allMovies = [];
    try {
      allMovies = await api.getMovieChannels("");
    } catch (_) {}
    if (!mounted) return;

    final adultCategoryIds = <String>{};
    for (final cat in movieCats) {
      if (cat.categoryName != null &&
          ProviderCurationRules.isAdultCategory(cat.categoryName!)) {
        if (cat.categoryId != null) {
          adultCategoryIds.add(cat.categoryId!);
        }
      }
    }
    final Map<String, String> searchCategoryNames = {
      for (final cat in movieCats)
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!,
    };
    // Never await search — Movies UI must not wait on the index.
    // ignore: unawaited_futures
    SearchIndexService.indexMovies(
      movies: allMovies,
      adultCategoryIds: adultCategoryIds,
      categoryIdToName: searchCategoryNames,
    );

    // One-pass movie rails (avoid per-category full-list rescans).
    final movieGroupWatch = Stopwatch()..start();
    if (movieCats.isNotEmpty || allMovies.isNotEmpty) {
      final categories = movieCats.isNotEmpty
          ? movieCats
          : LocaleApi.getM3uMovieCategories();
      final normalCats = categories
          .where(
            (c) =>
                c.categoryName != null &&
                !ProviderCurationRules.isAdultCategory(c.categoryName!),
          )
          .toList();
      final sortedCats =
          ProviderCurationRules.sortCategoriesForNormalDashboard(normalCats);
      final byCat = <String, List<ChannelMovie>>{};
      var moviesUnassigned = 0;
      for (final ch in allMovies) {
        final id = ch.categoryId;
        if (id == null || id.isEmpty) {
          moviesUnassigned++;
          continue;
        }
        byCat.putIfAbsent(id, () => []).add(ch);
      }
      var rows = <TvChannelRow>[];
      for (final cat in sortedCats) {
        final catId = cat.categoryId;
        if (catId == null) continue;
        try {
          final chs = byCat[catId] ?? const <ChannelMovie>[];
          if (chs.isEmpty) continue;
          final sortedChs = ContentIntelligenceService.sortMovies(
            chs,
            profile,
            categories,
          );
          final records = <TvStreamRecord>[
            for (final ch in sortedChs)
              _movieStreamRecord(
                ch,
                cat.categoryName ?? 'Movie',
                providerCategoryId: cat.categoryId,
                providerCategoryName: cat.categoryName,
              ),
          ];
          if (records.isNotEmpty) {
            rows.add(
              TvChannelRow(
                title: cat.categoryName ?? 'Movies',
                streams: records,
              ),
            );
          }
        } catch (_) {}
      }

      // FIX 2: category metadata missing or produced zero rails.
      if (rows.isEmpty && allMovies.isNotEmpty) {
        final nameById = <String, String>{
          for (final c in [
            ...categories,
            ...LocaleApi.getM3uMovieCategories(),
          ])
            if (c.categoryId != null && c.categoryId!.isNotEmpty)
              c.categoryId!: (c.categoryName != null &&
                      c.categoryName!.trim().isNotEmpty)
                  ? c.categoryName!
                  : 'Movies',
        };
        final byOwn = <String, List<ChannelMovie>>{};
        moviesUnassigned = 0;
        for (final ch in allMovies) {
          final id = ch.categoryId;
          if (id == null || id.isEmpty) {
            moviesUnassigned++;
            byOwn.putIfAbsent('_none', () => []).add(ch);
          } else {
            byOwn.putIfAbsent(id, () => []).add(ch);
          }
        }
        for (final entry in byOwn.entries) {
          final label = nameById[entry.key] ?? 'Movies';
          final records = <TvStreamRecord>[
            for (final ch in entry.value)
              _movieStreamRecord(
                ch,
                label,
                providerCategoryId:
                    entry.key == '_none' ? ch.categoryId : entry.key,
                providerCategoryName: label,
              ),
          ];
          if (records.isNotEmpty) {
            rows.add(TvChannelRow(title: label, streams: records));
          }
        }
      }

      // Section 16: collapse provider year-bucket headings. FIX 2 rows stay
      // the input; catalog category metadata is not deleted.
      if (rows.isNotEmpty) {
        final presented = _presentMovieRows(rows);
        if (presented.isNotEmpty) {
          rows = presented;
        }
      }

      final assigned = rows.fold<int>(0, (n, r) => n + r.streams.length);
      debugPrint(
        '[MOVIES_PIPE] rawMovies=${allMovies.length} '
        'liveForContext=${allLives.length} '
        'movieCategories=${categories.length} '
        'generatedMovieRows=${rows.length} '
        'moviesAssignedToRows=$assigned '
        'moviesUnassigned=$moviesUnassigned '
        'shelfTitles=${rows.map((r) => r.title).join('|')}',
      );
      if (rows.isNotEmpty && _moviesRailStartedAt != null) {
        debugPrint(
          '[MOVIES_PIPE] timeToFirstMovieRowMs='
          '${DateTime.now().difference(_moviesRailStartedAt!).inMilliseconds}',
        );
      }

      CatalogPerf.span('movie_group_ms', movieGroupWatch.elapsedMilliseconds);
      CatalogPerf.timeline('MOVIES_GROUP_READY');
      if (mounted) {
        if (rows.isNotEmpty) {
          setState(() {
            _movieRows = rows;
            _isMoviesRefreshing = false;
          });
          CatalogPerf.mark('firstMovieMs');
          if (_moviesRailStartedAt != null) {
            CatalogPerf.span(
              'movie_first_row_ms',
              DateTime.now()
                  .difference(_moviesRailStartedAt!)
                  .inMilliseconds,
            );
          }
          CatalogPerf.spanFromAnchor(
            'movie_first_row_from_tab_ms',
            'movies_tab',
          );
          CatalogPerf.count('movieRowsPublished', rows.length);
          CatalogPerf.count('movieRowCount', rows.length);
          CatalogPerf.count('movieCount', allMovies.length);
          CatalogPerf.timeline('MOVIES_FIRST_ROW');
          CatalogPerf.flush('first_movie_ui');
          _enqueueMovieTmdb();
        } else {
          setState(() => _isMoviesRefreshing = false);
        }
      }
    } else if (mounted) {
      setState(() => _isMoviesRefreshing = false);
    }
  }

  Future<void> _loadSeriesRails({
    required IpTvApi api,
    required UserPreferenceProfile profile,
    required List<CategoryModel> seriesCats,
  }) async {
    CatalogPerf.timeline('SERIES_START');
    await LocaleApi.warmM3uSeriesCache();
    CatalogPerf.timeline('SERIES_CACHE_READY');
    if (!mounted) return;

    if (seriesCats.isEmpty) {
      final s = context.read<SeriesCatyBloc>().state;
      if (s is SeriesCatySuccess) {
        seriesCats = s.categories;
      } else {
        seriesCats = LocaleApi.getM3uSeriesCategories();
      }
      if (seriesCats.isNotEmpty) {
        context.read<SeriesCatyBloc>().add(HydrateSeriesCategories(seriesCats));
      }
    }

    List<ChannelSerie> allSeries = [];
    try {
      allSeries = await api.getSeriesChannels("");
    } catch (_) {}
    if (!mounted) return;

    final adultCategoryIds = <String>{};
    for (final cat in seriesCats) {
      if (cat.categoryName != null &&
          ProviderCurationRules.isAdultCategory(cat.categoryName!)) {
        if (cat.categoryId != null) adultCategoryIds.add(cat.categoryId!);
      }
    }
    final searchCategoryNames = <String, String>{
      for (final cat in seriesCats)
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!,
    };
    // ignore: unawaited_futures
    SearchIndexService.indexSeries(
      series: allSeries,
      adultCategoryIds: adultCategoryIds,
      categoryIdToName: searchCategoryNames,
    );

    final seriesGroupWatch = Stopwatch()..start();
    if (seriesCats.isNotEmpty || allSeries.isNotEmpty) {
      final categories = seriesCats.isNotEmpty
          ? seriesCats
          : LocaleApi.getM3uSeriesCategories();
      final normalCats = categories
          .where(
            (c) =>
                c.categoryName != null &&
                !ProviderCurationRules.isAdultCategory(c.categoryName!),
          )
          .toList();
      final sortedCats =
          ProviderCurationRules.sortCategoriesForNormalDashboard(normalCats);
      final byCat = <String, List<ChannelSerie>>{};
      var seriesUnassigned = 0;
      for (final ch in allSeries) {
        final id = ch.categoryId;
        if (id == null || id.isEmpty) {
          seriesUnassigned++;
          continue;
        }
        byCat.putIfAbsent(id, () => []).add(ch);
      }
      Map<String, double> watchById = const {};
      try {
        final watching = context.read<WatchingCubit>().state.series;
        watchById = {
          for (final w in watching)
            if (w.durationStrm > 0)
              w.streamId: (w.sliderValue / w.durationStrm).clamp(0.0, 1.0),
        };
      } catch (_) {}
      var rows = <TvChannelRow>[];
      for (final cat in sortedCats) {
        final catId = cat.categoryId;
        if (catId == null) continue;
        try {
          final chs = byCat[catId] ?? const <ChannelSerie>[];
          if (chs.isEmpty) continue;
          final sortedChs = ContentIntelligenceService.sortSeries(
            chs,
            profile,
            categories,
          );
          final records = <TvStreamRecord>[
            for (final ch in sortedChs)
              _seriesStreamRecord(
                ch,
                cat.categoryName ?? 'Series',
                providerCategoryId: cat.categoryId,
                providerCategoryName: cat.categoryName,
                watchProgress: watchById[ch.seriesId ?? ''],
              ),
          ];
          if (records.isNotEmpty) {
            rows.add(
              TvChannelRow(
                title: cat.categoryName ?? 'Series Shows',
                streams: SeriesRailGrouper.groupForRail(records),
              ),
            );
          }
        } catch (_) {}
      }

      // FIX 2: category metadata missing or produced zero rails.
      // Content data > category metadata — never publish an empty Series
      // tab when valid series records exist.
      if (rows.isEmpty && allSeries.isNotEmpty) {
        final nameById = <String, String>{
          for (final c in [
            ...categories,
            ...LocaleApi.getM3uSeriesCategories(),
          ])
            if (c.categoryId != null && c.categoryId!.isNotEmpty)
              c.categoryId!: (c.categoryName != null &&
                      c.categoryName!.trim().isNotEmpty)
                  ? c.categoryName!
                  : 'All Series',
        };
        final byOwn = <String, List<ChannelSerie>>{};
        seriesUnassigned = 0;
        for (final ch in allSeries) {
          final id = ch.categoryId;
          if (id == null || id.isEmpty) {
            seriesUnassigned++;
            byOwn.putIfAbsent('_none', () => []).add(ch);
          } else {
            byOwn.putIfAbsent(id, () => []).add(ch);
          }
        }
        for (final entry in byOwn.entries) {
          final label = nameById[entry.key] ?? 'All Series';
          final records = <TvStreamRecord>[
            for (final ch in entry.value)
              _seriesStreamRecord(
                ch,
                label,
                providerCategoryId:
                    entry.key == '_none' ? ch.categoryId : entry.key,
                providerCategoryName: label,
                watchProgress: watchById[ch.seriesId ?? ''],
              ),
          ];
          if (records.isNotEmpty) {
            rows.add(
              TvChannelRow(
                title: label,
                streams: SeriesRailGrouper.groupForRail(records),
              ),
            );
          }
        }
      }

      final assigned = rows.fold<int>(0, (n, r) => n + r.streams.length);
      debugPrint(
        '[SERIES_PIPE] rawSeries=${allSeries.length} '
        'seriesCategories=${categories.length} '
        'generatedSeriesRows=${rows.length} '
        'seriesAssignedToRows=$assigned '
        'seriesUnassigned=$seriesUnassigned '
        'shelfTitles=${rows.map((r) => r.title).join('|')}',
      );
      CatalogPerf.span('series_group_ms', seriesGroupWatch.elapsedMilliseconds);
      CatalogPerf.timeline('SERIES_GROUP_READY');
      if (mounted) {
        if (rows.isNotEmpty) {
          setState(() {
            _seriesRows = rows;
            _isSeriesRefreshing = false;
          });
          CatalogPerf.mark('firstSeriesMs');
          if (_seriesRailStartedAt != null) {
            CatalogPerf.span(
              'series_first_row_ms',
              DateTime.now().difference(_seriesRailStartedAt!).inMilliseconds,
            );
          }
          CatalogPerf.count('seriesRowsPublished', rows.length);
          CatalogPerf.count('seriesRowCount', rows.length);
          CatalogPerf.count('seriesCount', allSeries.length);
          CatalogPerf.timeline('SERIES_FIRST_ROW');
          CatalogPerf.flush('first_series_ui');
          _enqueueSeriesTmdb();
        } else {
          setState(() => _isSeriesRefreshing = false);
        }
      }
    } else if (mounted) {
      setState(() => _isSeriesRefreshing = false);
    }
  }

  void _onMoviesCatalogReady() {
    if (!mounted) return;
    final cats = LocaleApi.getM3uMovieCategories();
    context.read<MovieCatyBloc>().add(HydrateMovieCategories(cats));
    debugPrint(
      '[MOVIES_PIPE] movieCategories=${cats.length} (bloc hydrate after movies)',
    );
    if (_movieRows.isEmpty && LocaleApi.getM3uMovieCount() > 0) {
      _loadMovieRails(
        api: IpTvApi(),
        profile: UserPreferenceProfile.load(),
        allLives: _tvAllLiveChannels,
        movieCats: cats,
      );
    }
  }

  void _onSeriesCatalogReady() {
    if (!mounted) return;
    final cats = LocaleApi.getM3uSeriesCategories();
    context.read<SeriesCatyBloc>().add(HydrateSeriesCategories(cats));
    debugPrint(
      '[SERIES_PIPE] seriesCategories=${cats.length} (bloc hydrate after series)',
    );
    if (_seriesRows.isEmpty && LocaleApi.getM3uSeriesCount() > 0) {
      _loadSeriesRails(
        api: IpTvApi(),
        profile: UserPreferenceProfile.load(),
        seriesCats: cats,
      );
    }
  }

  void _onXmlTvReady() {
    if (mounted) setState(() {});
  }

  static double? _parseRating(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final v = double.tryParse(raw.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Poster/year/TMDB optional — never drop a playable movie row.
  TvStreamRecord _movieStreamRecord(
    ChannelMovie ch,
    String subtitle, {
    String? providerCategoryId,
    String? providerCategoryName,
  }) {
    String streamUrl = '';
    if (ch.directSource != null && ch.directSource!.isNotEmpty) {
      streamUrl = ch.directSource!;
    } else if (ch.streamId != null) {
      streamUrl = ch.streamId!;
    }
    final poster = ArtworkUrlResolver.resolveVodPoster(
      streamIcon: ch.streamIcon,
    );
    final parsed = TitleNormalizer.parse(ch.name ?? '');
    final rating = _parseRating(ch.rating ?? ch.rating5based);
    final providerName = providerCategoryName ?? subtitle;
    final year = parsed.year ??
        CategoryPresentationMapper.yearFromCategoryName(providerName);
    final title = parsed.displayTitle.isEmpty
        ? (ch.name ?? 'Movie')
        : parsed.displayTitle;
    final key = TmdbEnrichmentWorker.cacheKeyFor(
      title,
      ch.streamId,
      type: ContentType.movie,
      year: year,
    );
    return TvStreamRecord(
      title: title,
      subtitle: subtitle,
      streamUrl: streamUrl,
      imageUrl: poster,
      backdropUrl: ArtworkUrlResolver.resolveHeroBackdrop(
        posterFallback: poster,
      ),
      streamId: ch.streamId,
      tvgId: ch.imdbId,
      imdbId: ch.imdbId,
      posterStyle: TvPosterStyle.vodPortrait,
      year: year,
      rating: rating,
      qualityLabel: parsed.qualityLabel,
      trailerUrl: ch.youtubeTrailer,
      enrichmentKey: key,
      providerCategoryId: providerCategoryId ?? ch.categoryId,
      providerCategoryName: providerName,
    );
  }

  /// Poster/year/TMDB optional — never drop a playable series row.
  TvStreamRecord _seriesStreamRecord(
    ChannelSerie ch,
    String subtitle, {
    String? providerCategoryId,
    String? providerCategoryName,
    double? watchProgress,
  }) {
    String streamUrl = '';
    if (ch.directSource != null && ch.directSource!.isNotEmpty) {
      streamUrl = ch.directSource!;
    } else if (ch.seriesId != null) {
      streamUrl = ch.seriesId!;
    }
    final poster = ArtworkUrlResolver.resolveVodPoster(
      cover: ch.cover,
    );
    final parsed = TitleNormalizer.parse(ch.name ?? '');
    final rating = _parseRating(ch.rating ?? ch.rating5based);
    final seriesTitle = parsed.displayTitle.isEmpty
        ? (ch.name ?? 'Series')
        : parsed.displayTitle;
    final key = TmdbEnrichmentWorker.cacheKeyFor(
      seriesTitle,
      ch.seriesId,
      type: ContentType.series,
      year: parsed.year,
      matchTitle: parsed.matchTitle,
    );
    return TvStreamRecord(
      title: seriesTitle,
      subtitle: providerCategoryName ?? subtitle,
      streamUrl: streamUrl,
      imageUrl: poster,
      backdropUrl: ArtworkUrlResolver.resolveHeroBackdrop(
        posterFallback: poster,
      ),
      streamId: ch.seriesId,
      posterStyle: TvPosterStyle.vodPortrait,
      year: parsed.year,
      rating: rating,
      qualityLabel: parsed.qualityLabel,
      season: parsed.season,
      episode: parsed.episode,
      badge: parsed.episodeBadge,
      overview: ch.plot,
      watchProgress: watchProgress,
      enrichmentKey: key,
      providerCategoryId: providerCategoryId ?? ch.categoryId,
      providerCategoryName: providerCategoryName ?? subtitle,
    );
  }

  /// Year-bucket `group-title`s become Classics / Movies / Recently Added.
  /// Provider category id/name stay on each record.
  List<TvChannelRow> _presentMovieRows(List<TvChannelRow> rows) {
    final shelves = CategoryPresentationMapper.presentMovies<TvStreamRecord>(
      groups: [
        for (final row in rows)
          PresentationSourceGroup(
            providerCategoryId: row.streams.isNotEmpty
                ? row.streams.first.providerCategoryId
                : null,
            providerCategoryName: row.title,
            items: row.streams,
          ),
      ],
      itemYear: (s) => s.year,
    );
    return [
      for (final shelf in shelves)
        if (shelf.items.isNotEmpty)
          TvChannelRow(title: shelf.title, streams: shelf.items),
    ];
  }

  TmdbEnqueueRequest _tmdbRequest(TvStreamRecord stream, ContentType type) {
    return TmdbEnqueueRequest(
      rawTitle: stream.title,
      providerId: stream.streamId,
      type: type,
      posterUrl: stream.imageUrl,
      backdropUrl: stream.backdropUrl,
      trailerUrl: stream.trailerUrl,
      overview: stream.overview,
      year: stream.year,
      rating: stream.rating,
      runtimeMinutes: stream.runtimeMinutes,
      imdbId: stream.imdbId ?? stream.tvgId,
    );
  }

  void _enqueueMovieTmdb() {
    // ignore: unawaited_futures
    TmdbEnrichmentWorker.instance.ensureStarted();
    final movieReqs = <TmdbEnqueueRequest>[];
    var rows = 0;
    for (final row in _movieRows) {
      if (rows >= 8) break;
      movieReqs.addAll(
        row.streams.take(24).map((s) => _tmdbRequest(s, ContentType.movie)),
      );
      rows++;
    }
    TmdbEnrichmentWorker.instance.enqueueMany(movieReqs);
  }

  void _enqueueSeriesTmdb() {
    // ignore: unawaited_futures
    TmdbEnrichmentWorker.instance.ensureStarted();
    var rows = 0;
    final seriesReqs = <TmdbEnqueueRequest>[];
    for (final row in _seriesRows) {
      if (rows >= 8) break;
      seriesReqs.addAll(
        row.streams.take(24).map((s) => _tmdbRequest(s, ContentType.series)),
      );
      rows++;
    }
    TmdbEnrichmentWorker.instance.enqueueMany(seriesReqs);
  }

  void _onPrimarySelected(int index) {
    if (index == _TvNav.favorites) {
      unawaited(_livePreview.release(reason: 'navigation'));
      Get.toNamed(screenFavourite)?.then((result) {
        TvBackGate.noteRoutePopped();
        if (!mounted) return;
        if (result == 'live') {
          _onPrimarySelected(_TvNav.live);
        } else if (result == 'movies') {
          _onPrimarySelected(_TvNav.movies);
        } else if (result == 'series') {
          _onPrimarySelected(_TvNav.series);
        } else {
          _navFocusNodes[_TvNav.favorites].requestFocus();
        }
        _syncLivePreview(immediate: true);
      });
      return;
    }
    if (index == _TvNav.history) {
      unawaited(_livePreview.release(reason: 'navigation'));
      Get.toNamed(screenCatchUp)?.then((_) {
        TvBackGate.noteRoutePopped();
        if (mounted) _navFocusNodes[_TvNav.history].requestFocus();
        _syncLivePreview(immediate: true);
      });
      return;
    }

    final leavingLive = _selectedNavIndex == _TvNav.live && index != _TvNav.live;
    final enteringLive = _selectedNavIndex != _TvNav.live && index == _TvNav.live;
    if (index == _TvNav.movies) {
      CatalogPerf.anchor('movies_tab');
    }
    if (leavingLive && index == _TvNav.movies) {
      unawaited(_leaveLiveForMovies());
      return;
    }
    setState(() {
      _selectedNavIndex = index;
      _railCollapsed = index == _TvNav.search;
    });
    if (leavingLive) {
      unawaited(_livePreview.release(reason: 'navigation'));
    } else if (enteringLive) {
      _syncLivePreview(immediate: true);
    }
  }

  void _onUtilitySelected(int index) {
    if (index == 0) {
      unawaited(_livePreview.release(reason: 'navigation'));
      Get.toNamed(screenSettings)?.then((_) {
        TvBackGate.noteRoutePopped();
        if (mounted && _utilityFocusNodes.isNotEmpty) {
          _utilityFocusNodes.first.requestFocus();
        }
        _syncLivePreview(immediate: true);
      });
    }
  }

  bool _isBackKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack;

  bool get _railHasFocus =>
      _navFocusNodes.any((n) => n.hasFocus) ||
      _utilityFocusNodes.any((n) => n.hasFocus);

  /// Search stays icon-only. Other tabs collapse when focus leaves the rail.
  void _syncRailCollapse() {
    if (!mounted) return;
    if (_selectedNavIndex == _TvNav.search) {
      if (!_railCollapsed) setState(() => _railCollapsed = true);
      return;
    }
    final collapse = !_railHasFocus;
    if (_railCollapsed != collapse) {
      setState(() => _railCollapsed = collapse);
    }
  }

  /// Back contract for the post-login shell:
  /// - Search tab → return to Live + expand rail (never dump to Google TV Home)
  /// - Content focus → move focus back to the selected rail item
  /// - Already on rail → ignore so the system can leave the app
  KeyEventResult _onShellKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_isBackKey(event.logicalKey)) return KeyEventResult.ignored;

    if (_selectedNavIndex == _TvNav.search) {
      setState(() {
        _selectedNavIndex = _TvNav.live;
        _railCollapsed = false;
      });
      _syncLivePreview(immediate: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navFocusNodes[_TvNav.live].requestFocus();
      });
      return KeyEventResult.handled;
    }

    if (!_railHasFocus) {
      final idx = _selectedNavIndex.clamp(0, _navFocusNodes.length - 1);
      _navFocusNodes[idx].requestFocus();
      logTvBack(
        screen: 'TvShell',
        source: 'focus',
        action: 'returnToRail',
        blockedDuplicate: false,
        routeBefore: Get.currentRoute,
      );
      return KeyEventResult.handled;
    }

    // Rail already focused. Swallow a leftover Back from a just-popped
    // child route so it cannot finish the Activity on the same press.
    if (TvBackGate.shouldSuppressShellExit()) {
      logTvBack(
        screen: 'TvShell',
        source: 'focus',
        action: 'blockedDuplicate',
        blockedDuplicate: true,
        routeBefore: Get.currentRoute,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePreview.dispose();
    FocusManager.instance.removeListener(_syncRailCollapse);
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    for (final node in _utilityFocusNodes) {
      node.dispose();
    }
    _retryFocus.dispose();
    XmlTvRepository.instance.removeListener(_onXmlTvReady);
    if (identical(
        IptvProviderSession.instance.onMoviesCatalogReady, _onMoviesCatalogReady)) {
      IptvProviderSession.instance.onMoviesCatalogReady = null;
    }
    if (identical(
        IptvProviderSession.instance.onSeriesCatalogReady, _onSeriesCatalogReady)) {
      IptvProviderSession.instance.onSeriesCatalogReady = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onShellKey,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Scaffold(
            backgroundColor: const Color(0xFF050A18),
            body: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: TmdbEnrichmentWorker.instance,
                  builder: (context, _) =>
                      TvShellBackdrop(imageUrl: _focusedBackdropUrl()),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x14FFFFFF),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      48,
                      _selectedNavIndex == _TvNav.movies ? 14 : 32,
                      48,
                      _selectedNavIndex == _TvNav.movies ? 14 : 32,
                    ),
                    child: Row(
                      children: [
                        TvNavigationRail(
                          items: _navItems,
                          utilityItems: _utilityItems,
                          selectedIndex: _selectedNavIndex,
                          focusNodes: _navFocusNodes,
                          utilityFocusNodes: _utilityFocusNodes,
                          collapsed: _railCollapsed,
                          onSelected: _onPrimarySelected,
                          onUtilitySelected: _onUtilitySelected,
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedNavIndex != _TvNav.movies &&
                                  _selectedNavIndex != _TvNav.series) ...[
                                _Header(
                                  selectedLabel:
                                      _navItems[_selectedNavIndex].label,
                                  subtitle: _headerSubtitle(),
                                  liveTone:
                                      _selectedNavIndex == _TvNav.live,
                                ),
                                const SizedBox(height: 22),
                              ],
                              Expanded(child: _buildContentPane()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentPane() {
    if (_selectedNavIndex == _TvNav.search) {
      return TvSearchScreen(
        embedded: true,
        onChannelSelected: widget.onChannelSelected,
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xCCF2F2F5),
                backgroundColor: Color(0x22FFFFFF),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Loading live TV',
              style: TextStyle(
                color: Color(0xFFF7F7F8),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final rows = _visibleRowsForTab(_selectedNavIndex);
    final isLive = _selectedNavIndex == _TvNav.live;
    final isMoviesTab = _selectedNavIndex == _TvNav.movies;
    final rawMovieCount =
        isMoviesTab ? LocaleApi.getM3uMovieCount() : 0;

    // FIX 4: Movies empty pane only when load is done AND raw count is 0.
    if (isMoviesTab &&
        rows.isEmpty &&
        (_loading || _isMoviesRefreshing || rawMovieCount > 0)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: kColorPrimary.withValues(alpha: 0.85),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Loading movies...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final isSeriesTab = _selectedNavIndex == _TvNav.series;
    final rawSeriesCount =
        isSeriesTab ? LocaleApi.getM3uSeriesCount() : 0;
    if (isSeriesTab &&
        rows.isEmpty &&
        (_loading || _isSeriesRefreshing || rawSeriesCount > 0)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: kColorPrimary.withValues(alpha: 0.85),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Loading series...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    // Empty Movies/Series: prefer capability-honest copy over generic “no movies”.
    if (!isLive && rows.isEmpty) {
      final vodM3u = StarliteVodM3uSession.instance;
      final native = ApolloNativeCatalogSession.instance;
      final caps = ProviderCapabilityInspector.instance.lastCapabilities ??
          ProviderCapabilityStore.instance.cached;
      final isStarlite =
          IptvProviderSession.instance.kind == IptvProviderKind.m3uStarlite;
      final isMovies = _selectedNavIndex == _TvNav.movies;
      final vodM3uTried = isStarlite &&
          (isMovies
              ? vodM3u.lastMoviesSyncAttempted
              : vodM3u.lastSeriesSyncAttempted);
      final vodM3uFailed = vodM3uTried &&
          (isMovies ? !vodM3u.lastMoviesSyncOk : !vodM3u.lastSeriesSyncOk);
      final needsNativeSession = isStarlite &&
          !vodM3uTried &&
          (native.needsStartupShowSession ||
              native.lastFailure == ApolloNativeAuthFailure.unauthorized ||
              native.lastFailure == ApolloNativeAuthFailure.badCredentials ||
              native.lastFailure == ApolloNativeAuthFailure.capturePending ||
              !native.lastSyncAttempted);
      final noVodApi = caps != null &&
          !caps.supportsVod &&
          !caps.supportsSeries &&
          caps.providerType != ProviderType.xtream &&
          !vodM3uTried;

      String title;
      String subtitle;
      if (vodM3uFailed) {
        title = isMovies
            ? 'Movies catalog unavailable'
            : 'Series catalog unavailable';
        subtitle = isMovies
            ? vodM3u.moviesEmptySubtitle
            : vodM3u.seriesEmptySubtitle;
      } else if (needsNativeSession) {
        title = isMovies
            ? 'Movies need provider VOD session'
            : 'Series need provider VOD session';
        subtitle = isMovies
            ? native.moviesEmptySubtitle
            : native.seriesEmptySubtitle;
      } else if (noVodApi) {
        title = isMovies
            ? 'Provider has no VOD API detected'
            : 'Provider has no Series API detected';
        subtitle = isMovies
            ? 'This connection looks like a Live playlist only. '
                'Movies appear when the provider exposes a VOD catalog '
                '(or items are present in the playlist).'
            : 'This connection looks like a Live playlist only. '
                'Series appear when the provider exposes a series catalog '
                '(or items are present in the playlist).';
      } else {
        title = isMovies ? 'Playlist has no movies' : 'Playlist has no series';
        subtitle = isMovies
            ? (isStarlite
                ? (vodM3uTried
                    ? vodM3u.moviesEmptySubtitle
                    : native.moviesEmptySubtitle)
                : 'No movie entries were found in the connected playlist.')
            : (isStarlite
                ? (vodM3uTried
                    ? vodM3u.seriesEmptySubtitle
                    : native.seriesEmptySubtitle)
                : 'No series entries were found in the connected playlist.');
      }

      return _TvRetryEmptyPane(
        focusNode: _retryFocus,
        onRetry: () async {
          final session = IptvProviderSession.instance;
          if (session.kind == IptvProviderKind.m3uStarlite) {
            if (isMovies) {
              final ok = await session.syncStarliteMoviesIfNeeded();
              if (!ok && LocaleApi.getM3uMovies().isEmpty) {
                await session.syncApolloNativeVodIfNeeded();
              }
              if (mounted) {
                _loadMovieRails(
                  api: IpTvApi(),
                  profile: UserPreferenceProfile.load(),
                  allLives: _tvAllLiveChannels,
                  movieCats: LocaleApi.getM3uMovieCategories(),
                );
              }
              return;
            }
            await session.syncStarliteSeriesIfNeeded();
            if (mounted) {
              _loadSeriesRails(
                api: IpTvApi(),
                profile: UserPreferenceProfile.load(),
                seriesCats: LocaleApi.getM3uSeriesCategories(),
              );
            }
            return;
          }
          _loadRealPlaylistContent();
        },
        title: title,
        subtitle: subtitle,
      );
    }

    final isVod = _selectedNavIndex == _TvNav.movies ||
        _selectedNavIndex == _TvNav.series;

    if (isMoviesTab) {
      return CinematicMoviesPage(
        rows: rows,
        onChannelSelected: _openMovieFromCatalog,
        onStreamFocused: (stream) {
          if (!mounted) return;
          setState(() => _focusedVodStream = stream);
          TmdbEnrichmentWorker.instance.prioritize(
            _tmdbRequest(stream, ContentType.movie),
          );
        },
        categoryChips: _movieRows
            .map((r) => r.title)
            .where((t) => t.isNotEmpty)
            .toList(growable: false),
        selectedCategory: _movieCategoryFilter,
        onCategorySelected: (value) {
          if (!mounted) return;
          setState(() => _movieCategoryFilter = value);
        },
      );
    }

    return TvChannelGrid(
      rows: rows,
      posterStyle: isVod
          ? TvPosterStyle.vodPortrait
          : TvPosterStyle.liveLandscape,
      onChannelSelected: isLive ? _openPlayback : widget.onChannelSelected,
      onLiveRecordSelected: isLive ? _watchLive : null,
      onStreamFocused: isLive
          ? _onLiveChannelFocused
          : isVod
              ? (stream) {
                  if (!mounted) return;
                  setState(() => _focusedVodStream = stream);
                  TmdbEnrichmentWorker.instance.prioritize(
                    _tmdbRequest(
                      stream,
                      ContentType.series,
                    ),
                  );
                }
              : null,
      header: isLive
          ? _buildLiveTvHeader()
          : isVod
              ? _buildVodFocusHeader()
              : null,
    );
  }

  static bool _looksHd(String name) {
    final n = name.toUpperCase();
    return n.contains(' HD') ||
        n.endsWith('HD') ||
        n.contains('1080') ||
        n.contains('720') ||
        n.contains('4K') ||
        n.contains('UHD');
  }

  Widget? _buildVodFocusHeader() {
    final focused = _focusedVodStream ??
        (_selectedNavIndex == _TvNav.movies
            ? (_movieRows.isNotEmpty && _movieRows.first.streams.isNotEmpty
                ? _movieRows.first.streams.first
                : null)
            : (_seriesRows.isNotEmpty && _seriesRows.first.streams.isNotEmpty
                ? _seriesRows.first.streams.first
                : null));
    if (focused == null) return null;
    final isMovies = _selectedNavIndex == _TvNav.movies;
    final chipCats = isMovies
        ? _movieRows.map((r) => r.title).where((t) => t.isNotEmpty).toList()
        : const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMovies && chipCats.isNotEmpty) ...[
          TvLiveCategoryChips(
            categories: chipCats,
            selected: _movieCategoryFilter,
            onSelected: (value) {
              if (!mounted) return;
              setState(() => _movieCategoryFilter = value);
            },
          ),
          const SizedBox(height: 14),
        ],
        TvLiveFocusHero(
          stream: focused.copyWith(posterStyle: TvPosterStyle.vodPortrait),
          kicker: isMovies ? 'FEATURED' : 'SERIES',
          onWatch: focused.streamUrl.isEmpty
              ? null
              : () => widget.onChannelSelected(focused.streamUrl),
        ),
      ],
    );
  }

  Widget? _buildLiveTvHeader() {
    final activeMarket = LocalMarketService.getActiveMarket();
    final profile = UserPreferenceProfile.load();
    final hasLocal = profile.locationFeatureEnabled && activeMarket != null;
    final hasSpotlight = _tvSpotlightEvents.isNotEmpty;
    final hasPremiumPlus = _tvPremiumPlusItems.isNotEmpty;
    final focused = _focusedLiveStream;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TvLiveFocusHero(
          stream: focused,
          livePreview: _livePreview,
          kicker: 'LIVE',
          onWatch: focused == null || focused.streamUrl.isEmpty
              ? null
              : () => _watchLive(focused),
        ),
        const SizedBox(height: 14),
        TvLiveCategoryChips(
          categories: _liveRows.map((r) => r.title).toList(),
          selected: _liveCategoryFilter,
          onSelected: (value) {
            if (!mounted) return;
            setState(() => _liveCategoryFilter = value);
          },
        ),
        const SizedBox(height: 18),
        TvHomeRows(
          allLiveChannels: _tvAllLiveChannels,
          onChannelSelected: _openPlayback,
          onStreamFocused: _onLiveChannelFocused,
        ),
        if (hasSpotlight) ...[
          TvLiveSpotlightRow(
            events: _tvSpotlightEvents,
            allLiveChannels: _tvAllLiveChannels,
            onChannelSelected: _openPlayback,
          ),
          const SizedBox(height: 22),
        ],
        if (hasPremiumPlus) ...[
          TvPremiumPlusRow(
            items: _tvPremiumPlusItems,
            onPlayChannel: (ch) {
              if (ch is ChannelLive &&
                  ch.directSource != null &&
                  ch.directSource!.isNotEmpty) {
                unawaited(_openPlayback(ch.directSource!));
              } else if (ch is ChannelLive && ch.streamId != null) {
                unawaited(_openPlayback(ch.streamId!));
              }
            },
            onStreamFocused: _onLiveChannelFocused,
          ),
          const SizedBox(height: 22),
        ],
        if (hasLocal) ...[
          TvLocalTvRow(
            allLiveChannels: _tvAllLiveChannels,
            onChannelSelected: _openPlayback,
            onStreamFocused: _onLiveChannelFocused,
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  List<TvChannelRow> _visibleRowsForTab(int index) {
    switch (index) {
      case _TvNav.live:
        if (_liveCategoryFilter == null) return _liveRows;
        return _liveRows
            .where((r) => r.title == _liveCategoryFilter)
            .toList(growable: false);
      case _TvNav.movies:
        if (_movieCategoryFilter == null) return _movieRows;
        return _movieRows
            .where((r) => r.title == _movieCategoryFilter)
            .toList(growable: false);
      case _TvNav.series:
        if (_seriesCategoryFilter == null) return _seriesRows;
        return _seriesRows
            .where((r) => r.title == _seriesCategoryFilter)
            .toList(growable: false);
      default:
        return _liveRows;
    }
  }

  String? _focusedBackdropUrl() {
    if (_selectedNavIndex == _TvNav.live) {
      final focused = _focusedLiveStream;
      if (focused == null || focused.isVod) return null;
      final epg = XmlTvRepository.instance.nowNext(
        tvgId: focused.tvgId,
        channelName: focused.title,
        streamId: focused.streamId,
      );
      final icon = epg?.now.iconUrl;
      if (ArtworkUrlResolver.isUsableImageUrl(icon)) return icon;
      return null;
    }
    final focused = _focusedVodStream;
    if (focused == null) return null;
    final extra = focused.enrichmentKey == null
        ? null
        : TmdbEnrichmentWorker.instance.lookup(focused.enrichmentKey!);
    final url = extra?.backdropUrl ?? focused.backdropUrl;
    return ArtworkUrlResolver.isUsableImageUrl(url) ? url : null;
  }

  String _headerSubtitle() {
    switch (_selectedNavIndex) {
      case _TvNav.live:
        return '';
      case _TvNav.movies:
        return 'Browse movies in your connected catalog';
      case _TvNav.series:
        return 'Browse series in your connected catalog';
      case _TvNav.search:
        return 'Search your playlist';
      default:
        return '';
    }
  }
}

class _AppBuildBadge extends StatefulWidget {
  final bool quiet;

  const _AppBuildBadge({this.quiet = false});

  @override
  State<_AppBuildBadge> createState() => _AppBuildBadgeState();
}

class _AppBuildBadgeState extends State<_AppBuildBadge> {
  String _label = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      final build = info.buildNumber.trim();
      setState(() => _label = build.isEmpty ? info.version : 'v$build');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_label.isEmpty) return const SizedBox(width: 36, height: 22);
    return Text(
      _label,
      style: TextStyle(
        color: widget.quiet
            ? const Color(0xFFF2F2F5)
            : const Color(0xFF00D2FF),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String selectedLabel;
  final String? subtitle;
  final bool liveTone;

  const _Header({
    required this.selectedLabel,
    this.subtitle,
    this.liveTone = false,
  });

  @override
  Widget build(BuildContext context) {
    final meta = subtitle != null && subtitle!.isNotEmpty ? subtitle! : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!liveTone) ...[
          Icon(
            Icons.sensors_rounded,
            color: kColorPrimary.withValues(alpha: 0.9),
            size: 22,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: liveTone ? const Color(0xFFF7F7F8) : Colors.white,
                  fontSize: liveTone ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1.05,
                ),
              ),
              if (meta != null) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: liveTone
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0x3300A3FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: liveTone
                  ? Colors.white.withValues(alpha: 0.22)
                  : kColorPrimary.withValues(alpha: 0.7),
            ),
          ),
          child: _AppBuildBadge(quiet: liveTone),
        ),
        TvStatusClock(neutral: liveTone),
      ],
    );
  }
}

/// Focusable empty/retry pane for Movies & Series when playlist rows are empty.
class _TvRetryEmptyPane extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onRetry;
  final String title;
  final String subtitle;

  const _TvRetryEmptyPane({
    required this.focusNode,
    required this.onRetry,
    this.title = 'Nothing to browse here',
    this.subtitle =
        'No content is available in this section for the connected playlist. Press Retry, or Left for the menu.',
  });

  @override
  State<_TvRetryEmptyPane> createState() => _TvRetryEmptyPaneState();
}

class _TvRetryEmptyPaneState extends State<_TvRetryEmptyPane> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kColorCardLight.withValues(alpha: 0.85),
                kColorBackDark.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: kColorPrimary.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kColorPrimary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: kColorPrimary.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.playlist_remove_rounded,
                  size: 34,
                  color: kColorPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 17,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Focus(
                focusNode: widget.focusNode,
                onFocusChange: (v) => setState(() => _focused = v),
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.select ||
                      k == LogicalKeyboardKey.enter ||
                      k == LogicalKeyboardKey.gameButtonA) {
                    widget.onRetry();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: AnimatedScale(
                  scale: _focused ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      canRequestFocus: false,
                      borderRadius: BorderRadius.circular(16),
                      onTap: widget.onRetry,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: _focused
                              ? const LinearGradient(
                                  colors: [kColorPrimaryDark, kColorPrimary],
                                )
                              : null,
                          color: _focused
                              ? null
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            width: 2.5,
                            color: _focused
                                ? kColorFocus
                                : Colors.white.withValues(alpha: 0.22),
                          ),
                          boxShadow: _focused
                              ? [
                                  BoxShadow(
                                    color: kColorPrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 18,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            color: _focused ? Colors.black : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvUserGreeting extends StatelessWidget {
  const TvUserGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final username = state is AuthSuccess
            ? (state.user.userInfo?.username ?? 'Connected User')
            : 'Connected User';
        final expDateStr = state is AuthSuccess
            ? 'Exp: ${expirationDate(state.user.userInfo?.expDate)}'
            : 'Active Account';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                kColorPrimary.withValues(alpha: 0.10),
                kColorCardLight.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: kColorPrimary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kColorPrimaryDark, kColorPrimary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kColorPrimary.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: kColorPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kColorPrimary.withValues(alpha: 0.55),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          expDateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
