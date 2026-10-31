import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'live_rows_prebuild.dart';
import '../../repository/api/local_proximity.dart';
import '../../repository/api/location_preference_service.dart';
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
import '../../repository/provider/title_normalizer.dart';
import '../../repository/provider/tmdb_enrichment_worker.dart';
import '../../logic/cubits/watch/watching_cubit.dart';
import 'series_rails_isolate.dart';
import 'widgets/tv_live_category_chips.dart';
import 'widgets/tv_premium_plus_row.dart';
import 'widgets/tv_home_rows.dart';
import 'widgets/tv_shell_backdrop.dart';
import 'widgets/tv_status_clock.dart';
import 'tv_search_screen.dart';
import 'cinematic/cinematic_movies_page.dart';
import 'cinematic/cinematic_series_page.dart';
import 'live/live_hero_preview_controller.dart';
import 'live/live_preview_trace.dart';
import 'live/live_browse_gate.dart';

/// Four-screen view stays off unless a private test build passes
/// `--dart-define=ENABLE_MULTIVIEW=true`. Default builds do not.
const bool kMultiviewEnabled = bool.fromEnvironment(
  'ENABLE_MULTIVIEW',
  defaultValue: false,
);

class _NoopShellListenable extends Listenable {
  const _NoopShellListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

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

  /// Cards per shelf in the first (instant) publish; the rest fill in behind.
  static const int _kShelfHeadCount = 40;

  /// Shelves included in the first publish.
  static const int _kShelfHeadLimit = 40;
  final Stopwatch _sliceWatch = Stopwatch();
  int _seriesLoadGen = 0;
  bool _railHadFocus = false;

  /// Completes once Movies has its first shelves (or has nothing to show), so
  /// Series prep does not compete with Movies for the UI thread at startup.
  final Completer<void> _moviesHeadGate = Completer<void>();
  void _markMoviesHeadDone() {
    if (!_moviesHeadGate.isCompleted) _moviesHeadGate.complete();
  }

  Completer<void>? _seriesFullPassGate;

  /// Cooperative time-slicing for big catalog builds: after ~12ms of work,
  /// give the event loop a turn — and if a frame is pending (D-pad focus,
  /// video, animation), let it render first. Never forces extra frames.
  /// Returns false when the shell is gone and the caller should stop.
  Future<bool> _yieldIfBusy() async {
    if (!_sliceWatch.isRunning) _sliceWatch.start();
    if (_sliceWatch.elapsedMilliseconds < 12) return mounted;
    try {
      if (SchedulerBinding.instance.hasScheduledFrame) {
        await SchedulerBinding.instance.endOfFrame.timeout(
          const Duration(milliseconds: 48),
        );
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    } catch (_) {}
    _sliceWatch
      ..reset()
      ..start();
    return mounted;
  }

  /// The full Series catalog (100k+ items) is only built once the Series tab
  /// is opened; until then just the first shelves exist.
  void _releaseSeriesFullPass() {
    final gate = _seriesFullPassGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

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
  final FocusNode _multiviewFocus = FocusNode(debugLabel: 'MultiviewEntry');
  bool _multiviewOpening = false;

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

  /// Focused Live card. Only the hero/backdrop listen — moving focus never
  /// rebuilds the shell, rows or header.
  final ValueNotifier<TvStreamRecord?> _focusedLive =
      ValueNotifier<TvStreamRecord?>(null);
  TvStreamRecord? get _focusedLiveStream => _focusedLive.value;
  late UserPreferenceProfile _profile;
  bool _hasActiveMarket = false;
  String? _localMarketKey = '';
  List<String> _liveCategoryTitles = const [];
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

    CatalogPerf.timeline('SHELL_INIT');
    _refreshHeaderPrefs();
    // Rows built during the splash reel paint on this shell's first frame.
    final prebuilt = LiveRowsPrebuild.take();
    if (prebuilt != null) _applyLiveSnapshot(prebuilt);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navFocusNodes.isNotEmpty) {
        _navFocusNodes.first.requestFocus();
      }
      _loadRealPlaylistContent(prebuilt: prebuilt);
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
    _focusedLive.value = stream;
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

  /// Live → Series: drop the hero provider slot before the Series pane appears.
  Future<void> _leaveLiveForSeries() async {
    // ignore: avoid_print
    print('[PLAYBACK_HANDOFF] preview_release_requested reason=live_to_series');
    await _livePreview.stopAndRelease(reason: 'live_to_series');
    // ignore: avoid_print
    print(
      '[PLAYBACK_HANDOFF] preview_release_completed reason=live_to_series '
      'phase=${_livePreview.phase.name}',
    );
    if (!mounted) return;
    setState(() {
      _selectedNavIndex = _TvNav.series;
      _railCollapsed = false;
    });
  }

  /// Cinematic Movies/Series play. Await existing preview release, then
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

  void _loadRealPlaylistContent({LiveRowsSnapshot? prebuilt}) async {
    var snap = prebuilt;
    if (snap == null) {
      // Shell mounted before the splash-time prebuild finished — reuse it.
      final pending = LiveRowsPrebuild.pending;
      if (pending != null) {
        await pending;
        if (!mounted) return;
        final taken = LiveRowsPrebuild.take();
        if (taken != null) {
          snap = taken;
          setState(() => _applyLiveSnapshot(taken));
        }
      }
    }
    final hasPrebuilt = snap != null;

    if (mounted) {
      setState(() {
        if (!hasPrebuilt) {
          _loading = true;
          _setLiveRows(const []);
          _liveGroupCount = 0;
        }
        _isMoviesRefreshing = true;
        _isSeriesRefreshing = true;
        _moviesRailStartedAt = DateTime.now();
        _seriesRailStartedAt = DateTime.now();
        CatalogPerf.anchor('movie_rail');
        CatalogPerf.anchor('series_rail');
        CatalogPerf.timeline('MOVIES_START');
        CatalogPerf.timeline('SERIES_START');
        // FIX 3: keep last-known-good movie (and series) rows while refreshing.
      });
    }

    final liveCatyBloc = context.read<LiveCatyBloc>();
    final liveCatyState = liveCatyBloc.state;
    final movieCatyState = context.read<MovieCatyBloc>().state;
    final seriesCatyState = context.read<SeriesCatyBloc>().state;

    var movieCats = movieCatyState is MovieCatySuccess
        ? movieCatyState.categories
        : <CategoryModel>[];
    var seriesCats = seriesCatyState is SeriesCatySuccess
        ? seriesCatyState.categories
        : <CategoryModel>[];

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isMoviesRefreshing = false;
          _isSeriesRefreshing = false;
        });
      }
      return;
    }

    final api = IpTvApi();

    if (snap != null) {
      // Rows were painted on the shell's first frame.
      _publishedLive(
        rowCount: snap.rows.length,
        liveCount: snap.allLives.length,
      );
      _startVodRails(
        api: api,
        profile: snap.profile,
        allLives: snap.allLives,
        movieCats: movieCats,
        seriesCats: seriesCats,
      );
      return;
    }

    // Fast path: check in-memory/file M3U categories immediately before waiting on bloc.
    var liveCats = liveCatyState is LiveCatySuccess
        ? liveCatyState.categories
        : <CategoryModel>[];
    if (liveCats.isEmpty) {
      final cachedM3uCats = LocaleApi.getM3uCategories();
      if (cachedM3uCats.isNotEmpty) {
        liveCats = cachedM3uCats;
      }
    }
    if (liveCats.isEmpty && mounted) {
      if (liveCatyBloc.state is! LiveCatyLoading) {
        liveCatyBloc.add(GetLiveCategories());
      }
      try {
        final nextState = await liveCatyBloc.stream
            .firstWhere((s) => s is LiveCatySuccess)
            .timeout(const Duration(milliseconds: 1500));
        if (nextState is LiveCatySuccess) {
          liveCats = nextState.categories;
        }
      } catch (_) {}
      if (!mounted) return;
      if (liveCats.isEmpty) {
        liveCats = LocaleApi.getM3uCategories();
      }
    }

    final profile = UserPreferenceProfile.load();
    _profile = profile;

    List<ChannelLive> allLives = [];
    List<SpotlightEvent> spots = [];

    try {
      // Live-only on the critical path so splash -> shell is interactive ASAP.
      allLives = await api.getLiveChannels("");

      // Prefer durable group-title categories; never collapse to a fake "Live".
      if (liveCats.isEmpty && allLives.isNotEmpty) {
        final cached = LocaleApi.getM3uCategories();
        liveCats = cached.isNotEmpty
            ? cached
            : LiveRowsPrebuild.deriveCategories(allLives);
      }

      spots = await EventDiscoveryService.getSpotlightEvents(
        region: profile.region,
      );
    } catch (_) {}

    final premiumPlusItems = PremiumPlusService.matchPremiumPlusChannels(
      allLives,
      categoryIdToName: LiveRowsPrebuild.categoryIdToName(liveCats),
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

    final rows = await LiveRowsPrebuild.buildRows(
      liveCats: liveCats,
      allLives: allLives,
      profile: profile,
      market: LiveRowsPrebuild.activeLocalMarket(profile),
    );

    if (rows.isNotEmpty && mounted) {
      setState(() {
        _setLiveRows(rows);
        if (_focusedLiveStream == null && rows.first.streams.isNotEmpty) {
          _focusedLive.value = rows.first.streams.first;
        }
        // Live shell interactive — do not wait on Movies/Series rails.
        _loading = false;
      });
      _publishedLive(rowCount: rows.length, liveCount: allLives.length);
    } else if (mounted) {
      setState(() => _loading = false);
    }

    _startVodRails(
      api: api,
      profile: profile,
      allLives: allLives,
      movieCats: movieCats,
      seriesCats: seriesCats,
    );
  }

  void _setLiveRows(List<TvChannelRow> rows) {
    _liveRows = rows;
    _liveCategoryTitles = rows.map((r) => r.title).toList(growable: false);
  }

  /// Splash-time Live rows → shell state (call inside initState or setState).
  void _applyLiveSnapshot(LiveRowsSnapshot snap) {
    _tvAllLiveChannels = snap.allLives;
    _tvSpotlightEvents = snap.spots;
    _tvPremiumPlusItems = snap.premiumPlusItems;
    _liveGroupCount = snap.liveGroupCount;
    _profile = snap.profile;
    _setLiveRows(snap.rows);
    if (_focusedLiveStream == null &&
        snap.rows.isNotEmpty &&
        snap.rows.first.streams.isNotEmpty) {
      _focusedLive.value = snap.rows.first.streams.first;
    }
    _loading = false;
  }

  /// Profile/market reads for the Live header — once, not per focus move.
  void _refreshHeaderPrefs() {
    _profile = UserPreferenceProfile.load();
    final market = LocalMarketService.getActiveMarket();
    _hasActiveMarket = market != null;
    final marketKey = _profile.locationFeatureEnabled ? market?.id : null;
    if (marketKey != _localMarketKey) {
      final first = _localMarketKey == '';
      _localMarketKey = marketKey;
      // Market picked/changed in Settings: re-order local groups in place.
      if (!first && market != null && marketKey != null) {
        _setLiveRows([
          for (final row in _liveRows)
            LocalProximity.isLocalCategory(row.title)
                ? TvChannelRow(
                    title: row.title,
                    streams: LocalProximity.sortNearest(
                      row.streams,
                      market,
                      (r) => r.title,
                    ),
                  )
                : row,
        ]);
      }
    }
  }

  void _publishedLive({required int rowCount, required int liveCount}) {
    _syncLivePreview(immediate: true);
    // After the Welcome hold card has cleared.
    Future<void>.delayed(const Duration(seconds: 3), _maybeResolveLocalMarket);
    CatalogPerf.mark('firstLiveMs');
    CatalogPerf.mark('app_shell_ms');
    CatalogPerf.count('liveRowsPublished', rowCount);
    CatalogPerf.count('liveCount', liveCount);
    CatalogPerf.count('liveGroups', _liveGroupCount);
    CatalogPerf.flush('first_live_ui');
  }

  bool _localMarketChecked = false;

  /// Local channels nearest-first need a Local TV Market. On TV, ask once
  /// (coarse location → market only, no GPS stored); if already allowed,
  /// refresh silently. Settings → Local TV Market stays the manual override.
  Future<void> _maybeResolveLocalMarket() async {
    if (_localMarketChecked || !mounted) return;
    _localMarketChecked = true;
    final route = ModalRoute.of(context);
    debugPrint(
      '[LOCAL_MARKET] check enabled=${_profile.locationFeatureEnabled} '
      'market=${LocalMarketService.getActiveMarket()?.id} '
      'explainer=${LocationPreferenceService.shouldShowExplainer()} '
      'routeCurrent=${route?.isCurrent}',
    );
    if (!_profile.locationFeatureEnabled) return;
    if (LocalMarketService.getActiveMarket() != null) return;
    if (route != null && !route.isCurrent) return;

    if (!LocationPreferenceService.shouldShowExplainer()) {
      final status =
          await LocationPreferenceService.checkPermissionStatusSilently();
      if (status != 'granted') return;
      await LocationPreferenceService.requestLocationPersonalization();
      if (mounted) setState(_refreshHeaderPrefs);
      return;
    }

    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => const _TvLocalChannelsPrompt(),
    );
    TvBackGate.noteRoutePopped();
    if (!mounted) return;
    if (allow != true) {
      await LocationPreferenceService.markExplainerSeen(false);
      return;
    }
    await LocationPreferenceService.requestLocationPersonalization();
    if (!mounted) return;
    setState(_refreshHeaderPrefs);
    final market = LocalMarketService.getActiveMarket();
    Get.snackbar(
      'Local TV',
      market != null
          ? 'Showing ${market.displayName} channels first.'
          : 'Location unavailable — pick your area in Settings → Local TV Market.',
      snackPosition: SnackPosition.BOTTOM,
      colorText: Colors.white,
      backgroundColor: const Color(0xCC161618),
      margin: const EdgeInsets.all(24),
      duration: const Duration(seconds: 4),
    );
  }

  /// Independent Movies / Series pipelines — neither waits on the other.
  void _startVodRails({
    required IpTvApi api,
    required UserPreferenceProfile profile,
    required List<ChannelLive> allLives,
    required List<CategoryModel> movieCats,
    required List<CategoryModel> seriesCats,
  }) {
    // ignore: unawaited_futures
    _loadMovieRails(
      api: api,
      profile: profile,
      allLives: allLives,
      movieCats: movieCats,
    );
    // ignore: unawaited_futures
    _loadSeriesRails(api: api, profile: profile, seriesCats: seriesCats);
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

    // One-pass movie rails with progressive first-shelf publication & frame yielding.
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
      final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(
        normalCats,
      );
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
      // Pass 1: sort every shelf once and publish the first cards of each
      // right away so the page fills instantly. Pass 2 builds full shelves in
      // frame-sized slices so D-pad focus and video never stall.
      final shelves = <(CategoryModel, List<ChannelMovie>)>[];
      for (final cat in sortedCats) {
        final catId = cat.categoryId;
        if (catId == null) continue;
        final chs = byCat[catId];
        if (chs == null || chs.isEmpty) continue;
        try {
          shelves.add((
            cat,
            ContentIntelligenceService.sortMovies(chs, profile, categories),
          ));
        } catch (_) {}
        if (!await _yieldIfBusy()) return;
      }
      TvStreamRecord buildMovie(CategoryModel cat, ChannelMovie ch) =>
          _movieStreamRecord(
            ch,
            cat.categoryName ?? 'Movie',
            providerCategoryId: cat.categoryId,
            providerCategoryName: cat.categoryName,
          );
      if (_movieRows.isEmpty) {
        final heads = <TvChannelRow>[];
        for (final (cat, chs) in shelves.take(_kShelfHeadLimit)) {
          try {
            final head = [
              for (final ch in chs.take(_kShelfHeadCount)) buildMovie(cat, ch),
            ];
            if (head.isNotEmpty) {
              heads.add(
                TvChannelRow(
                  title: cat.categoryName ?? 'Movies',
                  streams: head,
                ),
              );
            }
          } catch (_) {}
          if (!await _yieldIfBusy()) return;
        }
        if (heads.isNotEmpty && _movieRows.isEmpty) {
          final earlyPresented = _presentMovieRows(heads);
          setState(() {
            _movieRows = earlyPresented.isNotEmpty ? earlyPresented : heads;
            _isMoviesRefreshing = false;
          });
          CatalogPerf.timeline('MOVIES_HEAD_READY');
          _markMoviesHeadDone();
          _enqueueMovieTmdb();
        }
      }
      var rows = <TvChannelRow>[];
      for (final (cat, chs) in shelves) {
        final records = <TvStreamRecord>[];
        for (final ch in chs) {
          try {
            records.add(buildMovie(cat, ch));
          } catch (_) {}
          if ((records.length & 63) == 0 && !await _yieldIfBusy()) return;
        }
        if (records.isNotEmpty) {
          rows.add(
            TvChannelRow(title: cat.categoryName ?? 'Movies', streams: records),
          );
        }
      }

      // FIX 2: category metadata missing or produced zero rails.
      if (rows.isEmpty && allMovies.isNotEmpty) {
        final nameById = <String, String>{
          for (final c in [...categories, ...LocaleApi.getM3uMovieCategories()])
            if (c.categoryId != null && c.categoryId!.isNotEmpty)
              c.categoryId!:
                  (c.categoryName != null && c.categoryName!.trim().isNotEmpty)
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
                providerCategoryId: entry.key == '_none'
                    ? ch.categoryId
                    : entry.key,
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
      _markMoviesHeadDone();
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
              DateTime.now().difference(_moviesRailStartedAt!).inMilliseconds,
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
    _markMoviesHeadDone();
  }

  Future<void> _loadSeriesRails({
    required IpTvApi api,
    required UserPreferenceProfile profile,
    required List<CategoryModel> seriesCats,
  }) async {
    CatalogPerf.timeline('SERIES_START');
    await _moviesHeadGate.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    if (!mounted) return;
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
      Map<String, double> watchById = const {};
      try {
        final watching = context.read<WatchingCubit>().state.series;
        watchById = {
          for (final w in watching)
            if (w.durationStrm > 0)
              w.streamId: (w.sliderValue / w.durationStrm).clamp(0.0, 1.0),
        };
      } catch (_) {}

      // Grouping, sorting and record building for 100k+ series ran on the UI
      // isolate (series_group_ms=64785 -> ANR). It now runs in a worker
      // isolate; the UI isolate only publishes the finished shelves.
      //
      // LOCK: publish [sliceSeriesHead] before the full compute. The Series
      // tab was waiting on every show (about two minutes) because heads and
      // the full catalog shared one await.
      final gen = ++_seriesLoadGen;
      final headSlice = sliceSeriesHead(allSeries, categories);
      if (headSlice.series.isNotEmpty) {
        try {
          final headBuilt = await compute(
            buildSeriesRailsInBackground,
            SeriesRailsJob(
              series: headSlice.series,
              categories: headSlice.categories,
              fallbackCategories: const [],
              profile: profile,
              watchById: watchById,
              headCount: _kShelfHeadCount,
              headLimit: _kShelfHeadLimit,
            ),
          );
          if (!mounted || gen != _seriesLoadGen) return;
          final headRows = headBuilt.rows.isNotEmpty
              ? headBuilt.rows
              : headBuilt.heads;
          if (headRows.isNotEmpty) {
            setState(() {
              _seriesRows = headRows;
              _isSeriesRefreshing = false;
            });
            CatalogPerf.timeline('SERIES_HEAD_READY');
            _enqueueSeriesTmdb();
          }
        } catch (e) {
          debugPrint('[SERIES_PIPE] head slice failed: ${e.runtimeType}');
        }
      }
      if (!mounted || gen != _seriesLoadGen) return;
      // Full catalog waits until Series is opened. The head slice is already
      // on screen, so this wait is not the spinner.
      if (_selectedNavIndex != _TvNav.series) {
        _releaseSeriesFullPass();
        final gate = _seriesFullPassGate = Completer<void>();
        await gate.future;
        if (!mounted || gen != _seriesLoadGen) return;
      }

      final SeriesRailsResult built;
      try {
        built = await compute(
          buildSeriesRailsInBackground,
          SeriesRailsJob(
            series: allSeries,
            categories: categories,
            fallbackCategories: LocaleApi.getM3uSeriesCategories(),
            profile: profile,
            watchById: watchById,
            headCount: _kShelfHeadCount,
            headLimit: _kShelfHeadLimit,
          ),
        );
      } catch (e) {
        debugPrint('[SERIES_PIPE] background build failed: $e');
        if (mounted) setState(() => _isSeriesRefreshing = false);
        return;
      }
      if (!mounted || gen != _seriesLoadGen) return;

      if (_seriesRows.isEmpty && built.heads.isNotEmpty) {
        setState(() {
          _seriesRows = built.heads;
          _isSeriesRefreshing = false;
        });
        CatalogPerf.timeline('SERIES_HEAD_READY');
        _enqueueSeriesTmdb();
      }

      final rows = built.rows;
      final assigned = rows.fold<int>(0, (n, r) => n + r.streams.length);
      debugPrint(
        '[SERIES_PIPE] perShow=${built.perShow} rawSeries=${allSeries.length} '
        'seriesCategories=${categories.length} shows=${built.showCount} '
        'generatedSeriesRows=${rows.length} '
        'seriesAssignedToRows=$assigned '
        'seriesUnassigned=${built.unassigned} '
        'shelfTitles=${rows.map((r) => '${r.title}:${r.streams.length}').join('|')}',
      );
      CatalogPerf.span('series_group_ms', seriesGroupWatch.elapsedMilliseconds);
      CatalogPerf.timeline('SERIES_GROUP_READY');
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
    final year =
        parsed.year ??
        CategoryPresentationMapper.yearFromCategoryName(providerName);
    final title = parsed.displayTitle.isEmpty
        ? (ch.name ?? 'Movie')
        : parsed.displayTitle;
    final key = TmdbEnrichmentWorker.cacheKeyFor(
      title,
      ch.streamId,
      type: ContentType.movie,
      year: year,
      matchTitle: parsed.matchTitle,
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
      cacheKey: stream.enrichmentKey,
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
    // Warm the disk cache only. Cards enqueue when a shelf builds them,
    // so rows past the first screen are not stuck behind a 192-item queue.
    // ignore: unawaited_futures
    TmdbEnrichmentWorker.instance.ensureStarted();
  }

  void _enqueueSeriesCard(TvStreamRecord stream) {
    // ignore: unawaited_futures
    TmdbEnrichmentWorker.instance.ensureStarted();
    TmdbEnrichmentWorker.instance.enqueue(
      _tmdbRequest(stream, ContentType.series),
    );
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

    final leavingLive =
        _selectedNavIndex == _TvNav.live && index != _TvNav.live;
    final enteringLive =
        _selectedNavIndex != _TvNav.live && index == _TvNav.live;
    if (index == _TvNav.movies) {
      CatalogPerf.anchor('movies_tab');
    }
    if (leavingLive && index == _TvNav.movies) {
      unawaited(_leaveLiveForMovies());
      return;
    }
    if (index == _TvNav.series) {
      _releaseSeriesFullPass();
    }
    if (leavingLive && index == _TvNav.series) {
      unawaited(_leaveLiveForSeries());
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

  /// Opens the 2×2 multiview route. Does not change preview request,
  /// stopAndRelease, or hero sync. Drops the one hero player first so the
  /// grid does not start a fifth player beside it.
  Future<void> _openMultiview() async {
    if (_multiviewOpening) return;
    _multiviewOpening = true;
    try {
      try {
        await _livePreview.release(reason: 'navigation');
      } catch (_) {}
      if (!mounted) return;
      await Get.toNamed(screenMultiview);
      TvBackGate.noteRoutePopped();
      if (!mounted) return;
      _syncLivePreview(immediate: true);
      _multiviewFocus.requestFocus();
    } finally {
      _multiviewOpening = false;
    }
  }

  void _onRightFromRail() {
    if (!mounted) return;
    // When directional right from a rail item doesn't find a geometrically aligned
    // child, advance focus into the active content pane.
    FocusScope.of(context).nextFocus();
  }

  void _onUtilitySelected(int index) {
    if (index == 0) {
      unawaited(_livePreview.release(reason: 'navigation'));
      Get.toNamed(screenSettings)?.then((_) {
        TvBackGate.noteRoutePopped();
        if (mounted) setState(_refreshHeaderPrefs);
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
    // D-pad Left from content lands on whichever rail item is level with the
    // focused row; always enter the rail on the section the user is in.
    final railFocused = _railHasFocus;
    final entering = railFocused && !_railHadFocus;
    _railHadFocus = railFocused;
    if (entering && _selectedNavIndex < _navFocusNodes.length) {
      final target = _navFocusNodes[_selectedNavIndex];
      if (!target.hasFocus) target.requestFocus();
    }
    if (_selectedNavIndex == _TvNav.search) {
      if (!_railCollapsed) setState(() => _railCollapsed = true);
      return;
    }
    final collapse = !_railHasFocus;
    if (_railCollapsed != collapse) {
      setState(() => _railCollapsed = collapse);
    }
  }

  bool _backDownConsumed = false;

  /// Back contract for the post-login shell:
  /// - Search tab → return to Live + expand rail (never dump to Google TV Home)
  /// - Content focus → move focus back to the selected rail item
  /// - Already on rail (non-Live) → return to Live rail + expand rail
  /// - Already on rail (Live) → ignore so the system can leave the app
  KeyEventResult _onShellKey(FocusNode _, KeyEvent event) {
    if (!_isBackKey(event.logicalKey)) return KeyEventResult.ignored;
    // Android fires system Back on key *up*. When a child route already
    // popped on this press's key down, its key up lands here — swallow it or
    // the Activity finishes (Settings -> Back used to exit the app).
    if (event is KeyUpEvent) {
      // Key down already acted on this press (e.g. focus -> rail): its key up
      // must not reach Android too, or one press also leaves the app.
      final consumed = _backDownConsumed;
      _backDownConsumed = false;
      return consumed || TvBackGate.shouldSuppressShellExit()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _backDownConsumed = false;

    if (_selectedNavIndex == _TvNav.search) {
      _backDownConsumed = true;
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
      _backDownConsumed = true;
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

    // Rail already focused. If not on the Live tab, Back returns to the Live rail.
    if (_selectedNavIndex != _TvNav.live) {
      _backDownConsumed = true;
      setState(() {
        _selectedNavIndex = _TvNav.live;
        _railCollapsed = false;
      });
      _syncLivePreview(immediate: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navFocusNodes[_TvNav.live].requestFocus();
      });
      logTvBack(
        screen: 'TvShell',
        source: 'focus',
        action: 'returnToLiveRail',
        blockedDuplicate: false,
        routeBefore: Get.currentRoute,
      );
      return KeyEventResult.handled;
    }

    // Live rail already focused. Swallow a leftover Back from a just-popped
    // child route so it cannot finish the Activity on the same press.
    if (TvBackGate.shouldSuppressShellExit()) {
      _backDownConsumed = true;
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
    _focusedLive.dispose();
    FocusManager.instance.removeListener(_syncRailCollapse);
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    for (final node in _utilityFocusNodes) {
      node.dispose();
    }
    _retryFocus.dispose();
    _multiviewFocus.dispose();
    XmlTvRepository.instance.removeListener(_onXmlTvReady);
    if (identical(
      IptvProviderSession.instance.onMoviesCatalogReady,
      _onMoviesCatalogReady,
    )) {
      IptvProviderSession.instance.onMoviesCatalogReady = null;
    }
    if (identical(
      IptvProviderSession.instance.onSeriesCatalogReady,
      _onSeriesCatalogReady,
    )) {
      IptvProviderSession.instance.onSeriesCatalogReady = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCinematicTab =
        _selectedNavIndex == _TvNav.movies ||
        _selectedNavIndex == _TvNav.series;
    final backdropKey = _focusedVodStream?.enrichmentKey;
    final backdropListenable = backdropKey == null
        ? const _NoopShellListenable()
        : TmdbEnrichmentWorker.instance.notifierFor(backdropKey);

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
                  listenable: Listenable.merge([
                    backdropListenable,
                    _focusedLive,
                  ]),
                  builder: (context, _) =>
                      TvShellBackdrop(imageUrl: _focusedBackdropUrl()),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x14FFFFFF)),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      48,
                      isCinematicTab ? 14 : 32,
                      48,
                      isCinematicTab ? 14 : 32,
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
                          onRightFromRail: _onRightFromRail,
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isCinematicTab) ...[
                                _Header(
                                  selectedLabel:
                                      _navItems[_selectedNavIndex].label,
                                  subtitle: _headerSubtitle(),
                                  liveTone: _selectedNavIndex == _TvNav.live,
                                  multiviewFocus:
                                      kMultiviewEnabled &&
                                          _selectedNavIndex == _TvNav.live
                                      ? _multiviewFocus
                                      : null,
                                  onMultiview:
                                      kMultiviewEnabled &&
                                          _selectedNavIndex == _TvNav.live
                                      ? () => unawaited(_openMultiview())
                                      : null,
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
    final rawMovieCount = isMoviesTab ? LocaleApi.getM3uMovieCount() : 0;

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
    final rawSeriesCount = isSeriesTab ? LocaleApi.getM3uSeriesCount() : 0;
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
      final caps =
          ProviderCapabilityInspector.instance.lastCapabilities ??
          ProviderCapabilityStore.instance.cached;
      final isStarlite =
          IptvProviderSession.instance.kind == IptvProviderKind.m3uStarlite;
      final isMovies = _selectedNavIndex == _TvNav.movies;
      final vodM3uTried =
          isStarlite &&
          (isMovies
              ? vodM3u.lastMoviesSyncAttempted
              : vodM3u.lastSeriesSyncAttempted);
      final vodM3uFailed =
          vodM3uTried &&
          (isMovies ? !vodM3u.lastMoviesSyncOk : !vodM3u.lastSeriesSyncOk);
      final needsNativeSession =
          isStarlite &&
          !vodM3uTried &&
          (native.needsStartupShowSession ||
              native.lastFailure == ApolloNativeAuthFailure.unauthorized ||
              native.lastFailure == ApolloNativeAuthFailure.badCredentials ||
              native.lastFailure == ApolloNativeAuthFailure.capturePending ||
              !native.lastSyncAttempted);
      final noVodApi =
          caps != null &&
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

    final isVod =
        _selectedNavIndex == _TvNav.movies ||
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

    if (isSeriesTab) {
      return CinematicSeriesPage(
        rows: rows,
        onChannelSelected: _openMovieFromCatalog,
        onStreamFocused: (stream) {
          if (!mounted) return;
          setState(() => _focusedVodStream = stream);
          TmdbEnrichmentWorker.instance.prioritize(
            _tmdbRequest(stream, ContentType.series),
          );
        },
        onCardNearView: _enqueueSeriesCard,
        categoryChips: _seriesRows
            .map((r) => r.title)
            .where((t) => t.isNotEmpty)
            .toList(growable: false),
        selectedCategory: _seriesCategoryFilter,
        onCategorySelected: (value) {
          if (!mounted) return;
          setState(() => _seriesCategoryFilter = value);
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
                _tmdbRequest(stream, ContentType.series),
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

  Widget? _buildVodFocusHeader() {
    final focused =
        _focusedVodStream ??
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
    final hasLocal = _profile.locationFeatureEnabled && _hasActiveMarket;
    final hasSpotlight = _tvSpotlightEvents.isNotEmpty;
    final hasPremiumPlus = _tvPremiumPlusItems.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TvStreamRecord?>(
          valueListenable: _focusedLive,
          builder: (context, focused, _) => TvLiveFocusHero(
            stream: focused,
            livePreview: _livePreview,
            kicker: 'LIVE',
            onWatch: focused == null || focused.streamUrl.isEmpty
                ? null
                : () => _watchLive(focused),
          ),
        ),
        const SizedBox(height: 14),
        TvLiveCategoryChips(
          categories: _liveCategoryTitles,
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

/// One-time TV opt-in for local channel ordering (D-pad friendly).
class _TvLocalChannelsPrompt extends StatelessWidget {
  const _TvLocalChannelsPrompt();

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    return Dialog(
      backgroundColor: const Color(0xFF161618),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 52,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              const Text(
                'Show local channels first?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'TV Parser uses your approximate location to put your local '
                'channels first in Live TV. Only your TV market is saved — '
                'you can change it anytime in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    autofocus: true,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(220, 56),
                      shape: buttonShape,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Use my location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 56),
                      side: const BorderSide(color: Colors.white24),
                      shape: buttonShape,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Not now',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        color: widget.quiet ? const Color(0xFFF2F2F5) : const Color(0xFF00D2FF),
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
  final FocusNode? multiviewFocus;
  final VoidCallback? onMultiview;

  const _Header({
    required this.selectedLabel,
    this.subtitle,
    this.liveTone = false,
    this.multiviewFocus,
    this.onMultiview,
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
        if (onMultiview != null && multiviewFocus != null) ...[
          TextButton(
            focusNode: multiviewFocus,
            onPressed: onMultiview,
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(Color(0xFFF7F7F8)),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return const Color(0x33FFFFFF);
                }
                return const Color(0x14FFFFFF);
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return const BorderSide(color: Colors.white, width: 2);
                }
                return const BorderSide(color: Color(0x38FFFFFF));
              }),
              minimumSize: const WidgetStatePropertyAll(Size(148, 48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            child: const Text(
              'Multiview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
        ],
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
            border: Border.all(color: kColorPrimary.withValues(alpha: 0.28)),
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
                                    color: kColorPrimary.withValues(alpha: 0.4),
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
            border: Border.all(color: kColorPrimary.withValues(alpha: 0.18)),
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
