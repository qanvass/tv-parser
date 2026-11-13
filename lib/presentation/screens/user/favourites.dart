part of '../screens.dart';

/// Sections of the Favourites screen, in sidebar order.
enum _FavSection { live, movies, series, all, recent, continueWatching }

enum _FavKind { live, movie, series }

/// Focus zones for D-pad navigation.
enum _FavZone { top, side, view, content }

/// One card. Either a saved favourite ([favorite]) or a watch-history row
/// ([watch]) in Continue Watching.
class _FavEntry {
  final _FavKind kind;
  final String title;
  final String? image;
  final Object? favorite;
  final WatchingModel? watch;

  const _FavEntry({
    required this.kind,
    required this.title,
    this.image,
    this.favorite,
    this.watch,
  });

  double? get progress {
    final w = watch;
    if (w == null || w.durationStrm <= 0) return null;
    return (w.sliderValue / w.durationStrm).clamp(0.0, 1.0);
  }
}

const Color _kFavInk = Color(0xFF070B18);
const Color _kFavPanel = Color(0xFF111833);
const Color _kFavBlue = Color(0xFF2B6BFF);
const Color _kFavViolet = Color(0xFF7B3DFF);
const Color _kFavStar = Color(0xFFFFB627);
const Color _kFavLive = Color(0xFFE5202E);

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen>
    with HoldToFavorite<FavouriteScreen> {
  _FavZone _zone = _FavZone.side;
  _FavSection _section = _FavSection.live;

  /// Top bar: 0 Search, 1 Live TV, 2 Movies, 3 Series, 4 Favourites, 5 Settings.
  int _topIdx = 4;
  static const int _topCount = 6;

  /// View toggle focus: 0 grid, 1 list.
  int _viewIdx = 0;
  bool _listMode = false;

  /// Focused card per section.
  final List<int> _focusIdx = List<int>.filled(_FavSection.values.length, 0);

  final _scroll = ScrollController();
  final _navFocus = FocusNode();
  double _rowExtent = 190;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _navFocus.dispose();
    super.dispose();
  }

  bool get _narrow => MediaQuery.sizeOf(context).width < 600;

  // ── Data ────────────────────────────────────────────────────────────────

  static _FavEntry _liveEntry(ChannelLive c) => _FavEntry(
    kind: _FavKind.live,
    title: c.name ?? '',
    image: c.streamIcon,
    favorite: c,
  );

  static _FavEntry _movieEntry(ChannelMovie m) => _FavEntry(
    kind: _FavKind.movie,
    title: m.name ?? '',
    image: m.streamIcon,
    favorite: m,
  );

  static _FavEntry _serieEntry(ChannelSerie s) => _FavEntry(
    kind: _FavKind.series,
    title: s.name ?? '',
    image: s.cover,
    favorite: s,
  );

  static _FavEntry _watchEntry(_FavKind kind, WatchingModel w) => _FavEntry(
    kind: kind,
    title: kind == _FavKind.live
        ? w.title
        : TitleNormalizer.parse(w.title).displayTitle.isEmpty
        ? w.title
        : TitleNormalizer.parse(w.title).displayTitle,
    image: w.image.isNotEmpty ? w.image : null,
    watch: w,
  );

  WatchingState? _watchState() {
    try {
      return context.read<WatchingCubit>().state;
    } catch (_) {
      return null;
    }
  }

  List<_FavEntry> _entriesFor(_FavSection section, FavoritesState fav) {
    switch (section) {
      case _FavSection.live:
        return [for (final c in fav.lives) _liveEntry(c)];
      case _FavSection.movies:
        return [for (final m in fav.movies) _movieEntry(m)];
      case _FavSection.series:
        return [for (final s in fav.series) _serieEntry(s)];
      case _FavSection.all:
        return [
          for (final c in fav.lives) _liveEntry(c),
          for (final m in fav.movies) _movieEntry(m),
          for (final s in fav.series) _serieEntry(s),
        ];
      case _FavSection.recent:
        // Each saved list is newest-first. There is no saved time to merge
        // the three lists by, so the newest of each kind is shown in turn.
        return [
          for (final c in fav.lives.take(8)) _liveEntry(c),
          for (final m in fav.movies.take(8)) _movieEntry(m),
          for (final s in fav.series.take(8)) _serieEntry(s),
        ];
      case _FavSection.continueWatching:
        final watch = _watchState();
        if (watch == null) return const [];
        return [
          for (final w in watch.movies.take(24))
            if (w.stream.isNotEmpty) _watchEntry(_FavKind.movie, w),
          for (final w in watch.series.take(24))
            if (w.stream.isNotEmpty) _watchEntry(_FavKind.series, w),
          for (final w in watch.live.take(12))
            if (w.stream.isNotEmpty) _watchEntry(_FavKind.live, w),
        ];
    }
  }

  List<_FavEntry> _currentEntries() =>
      _entriesFor(_section, context.read<FavoritesCubit>().state);

  int get _idx => _focusIdx[_section.index];

  void _setIdx(int v) => setState(() => _focusIdx[_section.index] = v);

  /// Poster sections use portrait tiles, the rest landscape tiles.
  bool get _posterSection =>
      _section == _FavSection.movies || _section == _FavSection.series;

  bool get _effectiveList => _listMode || (_narrow && !_posterSection);

  /// Columns of the grid as last laid out. Key handling reads this, so the
  /// D-pad always matches what is on screen.
  int _layoutCols = 4;

  int get _cols => _effectiveList ? 1 : _layoutCols;

  /// As many columns as fit without tiles getting too small to read.
  int _colsFor(double width) {
    const spacing = 14.0;
    final minTile = _posterSection ? 96.0 : 150.0;
    final maxCols = _posterSection ? 6 : 4;
    final fit = ((width - 12 + spacing) / (minTile + spacing)).floor();
    return fit.clamp(2, maxCols);
  }

  double get _tileAspect => _posterSection ? 2 / 3 : 1.19;

  static String _sectionLabel(_FavSection s) => switch (s) {
    _FavSection.live => 'Live TV',
    _FavSection.movies => 'Movies',
    _FavSection.series => 'Series',
    _FavSection.all => 'All Channels',
    _FavSection.recent => 'Recently Added',
    _FavSection.continueWatching => 'Continue Watching',
  };

  static IconData _sectionIcon(_FavSection s) => switch (s) {
    _FavSection.live => Icons.live_tv_rounded,
    _FavSection.movies => Icons.local_movies_rounded,
    _FavSection.series => Icons.movie_creation_rounded,
    _FavSection.all => Icons.grid_view_rounded,
    _FavSection.recent => Icons.schedule_rounded,
    _FavSection.continueWatching => Icons.play_circle_outline_rounded,
  };

  String get _subtitle => switch (_section) {
    _FavSection.live => 'Your saved channels in one place',
    _FavSection.movies => 'Your saved movies in one place',
    _FavSection.series => 'Your saved series in one place',
    _FavSection.all => 'Everything you saved in one place',
    _FavSection.recent => 'Your latest saved picks',
    _FavSection.continueWatching => 'Pick up where you left off',
  };

  String _countLabel(int n) {
    final noun = switch (_section) {
      _FavSection.live => n == 1 ? 'Channel' : 'Channels',
      _FavSection.movies => n == 1 ? 'Movie' : 'Movies',
      _FavSection.series => 'Series',
      _FavSection.continueWatching => n == 1 ? 'Title' : 'Titles',
      _ => n == 1 ? 'Item' : 'Items',
    };
    return '$n $noun';
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _scrollTo(int idx) {
    if (!_scroll.hasClients) return;
    final row = idx ~/ _cols;
    final viewport = _scroll.position.viewportDimension;
    final target = (row * _rowExtent - (viewport - _rowExtent) / 2).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _selectSection(_FavSection s) {
    if (_section == s) return;
    setState(() => _section = s);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Same TV Back contract as CatchUp/Settings: handle goBack + escape, never
  /// swallow goBack with [KeyEventResult.handled] without popping to the shell.
  bool _isBackKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack;

  bool _isSelectKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.gameButtonA;

  final _backGate = TvBackGate();

  void _popToShell([String? result]) {
    // Focus-only Back (no PopScope). Gate blocks same-press double pop.
    if (!mounted) return;
    if (!_backGate.allow(screen: 'FavouriteScreen', source: 'focus')) return;
    if (!Navigator.of(context).canPop()) return;
    _backGate.markRouteExit();
    logTvBack(
      screen: 'FavouriteScreen',
      source: 'focus',
      action: 'popRoute',
      blockedDuplicate: false,
      routeBefore: Get.currentRoute,
    );
    Get.back(result: result);
  }

  void _activateTop(int i) {
    switch (i) {
      case 0:
        _popToShell('search');
      case 1:
        _popToShell('live');
      case 2:
        _popToShell('movies');
      case 3:
        _popToShell('series');
      case 5:
        _popToShell('settings');
      default:
        // Favourites: already here.
        setState(() => _zone = _FavZone.side);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final entries = _currentEntries();
    final count = entries.length;

    if (_zone == _FavZone.content && _idx < count) {
      final item = entries[_idx].favorite;
      if (item != null) {
        final result = favoriteKey(
          e,
          onOpen: () => _open(entries[_idx]),
          onFavorite: () => FavoriteActions.add(context, item),
        );
        if (result == KeyEventResult.handled) return result;
      }
    }

    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (_isBackKey(k)) {
      _popToShell();
      return KeyEventResult.handled;
    }

    switch (_zone) {
      case _FavZone.top:
        if (_narrow) {
          // Phones show the plain app bar: one Back button.
          if (k == LogicalKeyboardKey.arrowDown) {
            setState(() => _zone = _FavZone.side);
          } else if (_isSelectKey(k)) {
            _popToShell();
          }
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (_topIdx > 0) setState(() => _topIdx--);
        } else if (k == LogicalKeyboardKey.arrowRight) {
          if (_topIdx < _topCount - 1) setState(() => _topIdx++);
        } else if (k == LogicalKeyboardKey.arrowDown) {
          setState(() => _zone = _FavZone.side);
        } else if (_isSelectKey(k)) {
          _activateTop(_topIdx);
        }
        return KeyEventResult.handled;

      case _FavZone.side:
        final sections = _visibleSections;
        final pos = sections.indexOf(_section);
        if (k == LogicalKeyboardKey.arrowUp) {
          if (pos > 0) {
            _selectSection(sections[pos - 1]);
          } else {
            setState(() {
              _zone = _FavZone.top;
              _topIdx = 4;
            });
          }
        } else if (k == LogicalKeyboardKey.arrowDown) {
          if (pos < sections.length - 1) _selectSection(sections[pos + 1]);
        } else if (k == LogicalKeyboardKey.arrowRight || _isSelectKey(k)) {
          // Stay on the sidebar when the section is empty: an empty grid has
          // nothing to focus and no visible focus ring.
          if (count > 0) setState(() => _zone = _FavZone.content);
        }
        return KeyEventResult.handled;

      case _FavZone.view:
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (_viewIdx > 0) {
            setState(() => _viewIdx--);
          } else {
            setState(() => _zone = _FavZone.side);
          }
        } else if (k == LogicalKeyboardKey.arrowRight) {
          if (_viewIdx < 1) setState(() => _viewIdx++);
        } else if (k == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _zone = _FavZone.top;
            _topIdx = 5;
          });
        } else if (k == LogicalKeyboardKey.arrowDown) {
          if (count > 0) setState(() => _zone = _FavZone.content);
        } else if (_isSelectKey(k)) {
          setState(() => _listMode = _viewIdx == 1);
          if (_scroll.hasClients) _scroll.jumpTo(0);
        }
        return KeyEventResult.handled;

      case _FavZone.content:
        final idx = _idx.clamp(0, count == 0 ? 0 : count - 1);
        final cols = _cols;
        if (count == 0) {
          setState(() => _zone = _FavZone.side);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (idx % cols == 0) {
            setState(() => _zone = _FavZone.side);
          } else {
            _setIdx(idx - 1);
            _scrollTo(idx - 1);
          }
        } else if (k == LogicalKeyboardKey.arrowRight) {
          if (idx < count - 1 && (idx + 1) % cols != 0) {
            _setIdx(idx + 1);
            _scrollTo(idx + 1);
          }
        } else if (k == LogicalKeyboardKey.arrowUp) {
          if (idx < cols) {
            setState(() => _zone = _narrow ? _FavZone.side : _FavZone.view);
          } else {
            _setIdx(idx - cols);
            _scrollTo(idx - cols);
          }
        } else if (k == LogicalKeyboardKey.arrowDown) {
          if (idx + cols < count) {
            _setIdx(idx + cols);
            _scrollTo(idx + cols);
          } else if (idx ~/ cols < (count - 1) ~/ cols) {
            // Last row is short: land on its final card.
            _setIdx(count - 1);
            _scrollTo(count - 1);
          }
        } else if (_isSelectKey(k)) {
          _open(entries[idx]);
        }
        return KeyEventResult.handled;
    }
  }

  /// Phones keep the three saved lists; the TV layout shows every section.
  List<_FavSection> get _visibleSections => _narrow
      ? const [_FavSection.live, _FavSection.movies, _FavSection.series]
      : _FavSection.values;

  // ── Opening ─────────────────────────────────────────────────────────────

  Future<void> _playLiveFavorite(ChannelLive ch) async {
    final link = await PlaybackUrlBuilder.resolveLivePlaybackUrl(ch);
    if (link.isEmpty || !mounted) return;
    Get.to(
      () => LivePlayerScreen(
        link: link,
        title: ch.name ?? '',
        streamIcon: ch.streamIcon,
        streamId: ch.streamId,
      ),
    );
  }

  void _open(_FavEntry entry) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final watch = entry.watch;
    if (watch != null) {
      _openWatch(entry.kind, watch);
      return;
    }
    final item = entry.favorite;
    if (item is ChannelLive) {
      _playLiveFavorite(item);
    } else if (item is ChannelMovie) {
      final title = item.name?.trim().toLowerCase() ?? '';
      if (title.contains('reasonable doubt') || title.contains('snowfall')) {
        Get.to(
          () => SerieContent(
            channelSerie: ChannelSerie(
              seriesId: item.streamId,
              name: item.name,
              cover: item.streamIcon,
              directSource: item.directSource,
              categoryId: item.categoryId,
            ),
            videoId: item.streamId ?? '',
          ),
        );
        return;
      }
      if (isTv(context)) {
        _openMovieTv(item);
      } else {
        Get.to(
          () => MobileDetailScreen(
            movie: item,
            onPlayTap: () {
              Get.back();
              _playMovieMobile(item);
            },
          ),
        );
      }
    } else if (item is ChannelSerie) {
      Get.to(
        () => SerieContent(channelSerie: item, videoId: item.seriesId ?? ''),
      );
    }
  }

  void _openWatch(_FavKind kind, WatchingModel w) {
    if (w.stream.isEmpty) return;
    if (kind == _FavKind.live) {
      Get.to(
        () => LivePlayerScreen(
          link: w.stream,
          title: w.title,
          streamId: w.streamId,
          streamIcon: w.image.isNotEmpty ? w.image : null,
        ),
      );
      return;
    }
    Get.to(
      () => MoviePlayerScreen(
        link: w.stream,
        title: w.title,
        streamId: w.streamId,
        image: w.image.isNotEmpty ? w.image : null,
        recordHistory: true,
        historyIsSeries: kind == _FavKind.series,
        startAt: Duration(seconds: w.sliderValue.round()),
      ),
    );
  }

  /// Playlist movies have no provider detail API (MovieContent can't play them).
  void _openMovieTv(ChannelMovie m) {
    if ((m.directSource ?? '').startsWith('http')) {
      _playMovieMobile(m);
    } else {
      Get.to(() => MovieContent(channelMovie: m, videoId: m.streamId ?? ''));
    }
  }

  Future<void> _playMovieMobile(ChannelMovie movie) async {
    final direct = movie.directSource?.trim() ?? '';
    final streamUrl = direct.startsWith('http')
        ? direct
        : await PlaybackUrlBuilder.buildMovieUrl(
            movie.streamId ?? '',
            containerExtension: movie.containerExtension,
          );
    if (streamUrl.isEmpty || !mounted) return;
    StreamLauncher.openStreamWithBrandedLoading(
      context: context,
      streamUrl: streamUrl,
      playerBuilder: () => MoviePlayerScreen(
        link: streamUrl,
        title: movie.name ?? 'Stream',
        streamId: movie.streamId,
        image: movie.streamIcon,
        recordHistory: true,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Match Settings: Focus-only Back (no PopScope). PopScope(canPop:false)
    // + Focus goBack both calling Get.back() double-popped → Google TV Home.
    return Focus(
      focusNode: _navFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: _kFavInk,
        body: _narrow ? _buildNarrow() : _buildWide(),
      ),
    );
  }

  Widget _buildNarrow() {
    return Ink(
      decoration: kDecorBackground,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: IptvAppBar(
                title: 'Favourites',
                icon: FontAwesomeIcons.heart.data,
                onBack: _popToShell,
                focusedIndex: _zone == _FavZone.top ? 0 : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _buildNarrowTabs(),
          ),
          Container(height: 1, color: kColorCardLight),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildNarrowTabs() {
    final fav = context.watch<FavoritesCubit>().state;
    return Row(
      children: [
        for (final s in _visibleSections)
          Expanded(
            child: GestureDetector(
              onTap: () {
                _selectSection(s);
                setState(() => _zone = _FavZone.content);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _section == s
                      ? kColorPrimary.withValues(alpha: .18)
                      : kColorCardLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _section == s
                        ? kColorPrimary.withValues(alpha: .5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_sectionLabel(s)} (${_entriesFor(s, fav).length})',
                    style: Get.textTheme.bodySmall!.copyWith(
                      color: _section == s ? Colors.white : Colors.white60,
                      fontWeight: _section == s
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWide() {
    final fav = context.watch<FavoritesCubit>().state;
    final count = _entriesFor(_section, fav).length;
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: _FavBackdrop()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 204, child: _buildSidebar(fav)),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(count),
                            const SizedBox(height: 10),
                            Expanded(child: _buildContent()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    const labels = ['Search', 'Live TV', 'Movies', 'Series', 'Favourites'];
    const icons = [
      Icons.search_rounded,
      Icons.sensors_rounded,
      Icons.local_movies_rounded,
      Icons.movie_creation_rounded,
      Icons.star_rounded,
    ];
    final topFocused = _zone == _FavZone.top;
    // Tablets between phone and TV width: drop the wordmark and the labels
    // of inactive pills so the bar never overflows.
    final compact = MediaQuery.sizeOf(context).width < 900;
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          // Brand mark: the icon half of the stacked logo, wordmark beside it.
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.74,
              child: Image.asset(
                kIconLogoTransparent,
                height: 56,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            const Text(
              kAppName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
          ],
          const SizedBox(width: 22),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < labels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _FavPill(
                      icon: icons[i],
                      label: labels[i],
                      active: i == 4,
                      showLabel: !compact || i == 4,
                      focused: topFocused && _topIdx == i,
                      onTap: () => _activateTop(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FavPill(
            icon: Icons.settings_rounded,
            label: 'Settings',
            active: false,
            showLabel: !compact,
            focused: topFocused && _topIdx == 5,
            onTap: () => _activateTop(5),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(FavoritesState fav) {
    String label(_FavSection s) {
      switch (s) {
        case _FavSection.live:
          return 'Live TV (${fav.lives.length})';
        case _FavSection.movies:
          return 'Movies (${fav.movies.length})';
        case _FavSection.series:
          return 'Series (${fav.series.length})';
        default:
          return _sectionLabel(s);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kFavPanel.withValues(alpha: .92),
              const Color(0xFF0A0F22).withValues(alpha: .94),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
          boxShadow: [
            BoxShadow(
              color: _kFavViolet.withValues(alpha: .28),
              blurRadius: 26,
              offset: const Offset(0, 14),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'SECTIONS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final s in _FavSection.values)
                      _FavSectionTile(
                        icon: _sectionIcon(s),
                        label: label(s),
                        selected: _section == s,
                        focused: _section == s && _zone == _FavZone.side,
                        onTap: () {
                          _selectSection(s);
                          setState(() => _zone = _FavZone.side);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: _kFavStar, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Favourites',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            _FavViewToggle(
              listMode: _listMode,
              focusedIndex: _zone == _FavZone.view ? _viewIdx : null,
              onChanged: (list) {
                setState(() {
                  _listMode = list;
                  _viewIdx = list ? 1 : 0;
                });
                if (_scroll.hasClients) _scroll.jumpTo(0);
              },
            ),
            const SizedBox(width: 22),
            Text(
              _countLabel(count),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kFavViolet.withValues(alpha: .0),
                _kFavViolet,
                _kFavBlue.withValues(alpha: .55),
                Colors.transparent,
              ],
              stops: const [0, .12, .45, .9],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, favState) {
            final entries = _entriesFor(_section, favState);
            if (entries.isEmpty) return _emptyState();

            final focused = _idx.clamp(0, entries.length - 1);
            final contentFocus = _zone == _FavZone.content;

            if (_effectiveList) {
              _rowExtent = 58;
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 24),
                itemExtent: 58,
                itemCount: entries.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FavListRow(
                    entry: entries[i],
                    selected: i == focused,
                    focused: i == focused && contentFocus,
                    onTap: () => _tapEntry(i, entries[i]),
                    onLongPress: () => _holdEntry(entries[i]),
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, box) {
                final cols = _colsFor(box.maxWidth);
                _layoutCols = cols;
                const spacing = 14.0;
                const sidePad = 6.0;
                final tileW =
                    (box.maxWidth - sidePad * 2 - spacing * (cols - 1)) / cols;
                _rowExtent = tileW / _tileAspect + spacing;
                return GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(sidePad, 10, sidePad, 28),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: _tileAspect,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _FavTile(
                    entry: entries[i],
                    poster: _posterSection,
                    selected: i == focused,
                    focused: i == focused && contentFocus,
                    onTap: () => _tapEntry(i, entries[i]),
                    onLongPress: () => _holdEntry(entries[i]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _tapEntry(int i, _FavEntry entry) {
    setState(() {
      _focusIdx[_section.index] = i;
      _zone = _FavZone.content;
    });
    _open(entry);
  }

  void _holdEntry(_FavEntry entry) {
    final item = entry.favorite;
    if (item != null) FavoriteActions.add(context, item);
  }

  Widget _emptyState() {
    final label = switch (_section) {
      _FavSection.live => 'No favourite channels yet',
      _FavSection.movies => 'No favourite movies yet',
      _FavSection.series => 'No favourite series yet',
      _FavSection.continueWatching => 'Nothing to continue yet',
      _ => 'No favourites yet',
    };
    return Center(
      child: SingleChildScrollView(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: TvBrandedEmpty(
            icon: _section == _FavSection.continueWatching
                ? Icons.play_circle_outline_rounded
                : Icons.star_rounded,
            title: label,
            subtitle: _section == _FavSection.continueWatching
                ? 'Start a movie or an episode and it will be waiting for you here.'
                : 'Add items from Live TV, Movies, or Series. Build your list for quick access anytime.',
            extra: Row(
              children: [
                Expanded(
                  child: _FavJumpTile(
                    icon: Icons.live_tv_rounded,
                    label: 'Add favorite channels',
                    onTap: () => Get.back(result: 'live'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FavJumpTile(
                    icon: Icons.local_movies_rounded,
                    label: 'Save movies',
                    onTap: () => Get.back(result: 'movies'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FavJumpTile(
                    icon: Icons.tv_rounded,
                    label: 'Follow series',
                    onTap: () => Get.back(result: 'series'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Backdrop ────────────────────────────────────────────────────────────────

/// Dusk sky with a painted skyline behind the header. Drawn, not a photo, so
/// it costs no image memory.
class _FavBackdrop extends StatelessWidget {
  const _FavBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF141A3C), Color(0xFF0B1026), _kFavInk],
              stops: [0, .32, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.78, -1.15),
              radius: 1.05,
              colors: [
                const Color(0xFFFF8A3D).withValues(alpha: .62),
                const Color(0xFFD63D8F).withValues(alpha: .46),
                const Color(0xFF6A2BD9).withValues(alpha: .22),
                Colors.transparent,
              ],
              stops: const [0, .3, .58, 1],
            ),
          ),
        ),
        const CustomPaint(painter: _FavSkylinePainter()),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, _kFavInk],
              stops: [0, .2, .52],
            ),
          ),
        ),
      ],
    );
  }
}

class _FavSkylinePainter extends CustomPainter {
  const _FavSkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ground = size.height * .30;
    final startX = size.width * .40;
    final body = Paint()..color = const Color(0xFF0A0D20);
    final far = Paint()..color = const Color(0xFF1A1740).withValues(alpha: .85);
    final window = Paint()
      ..color = const Color(0xFFFFD27A).withValues(alpha: .55);

    // Deterministic pseudo-random heights so the skyline never changes.
    var seed = 7;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return (seed % 1000) / 1000.0;
    }

    // Far row: wider, lower, lighter.
    var x = startX;
    while (x < size.width) {
      final w = 22 + next() * 26;
      final h = size.height * (.05 + next() * .09);
      canvas.drawRect(Rect.fromLTWH(x, ground - h, w, h), far);
      x += w + 2;
    }

    // Near row with lit windows.
    x = startX + 12;
    while (x < size.width) {
      final w = 16 + next() * 22;
      final tall = next() > .78;
      final h = size.height * (tall ? .16 + next() * .10 : .04 + next() * .08);
      final rect = Rect.fromLTWH(x, ground - h, w, h);
      canvas.drawRect(rect, body);
      if (tall) {
        // Spire.
        canvas.drawRect(
          Rect.fromLTWH(x + w / 2 - 1, rect.top - 10, 2, 10),
          body,
        );
      }
      for (var wy = rect.top + 5; wy < ground - 4; wy += 7) {
        for (var wx = x + 3; wx < x + w - 3; wx += 5) {
          if (next() > .62) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 2, 2.5), window);
          }
        }
      }
      x += w + 3;
    }
  }

  @override
  bool shouldRepaint(covariant _FavSkylinePainter oldDelegate) => false;
}

// ─── Top bar pill ────────────────────────────────────────────────────────────

class _FavPill extends StatelessWidget {
  const _FavPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.focused,
    required this.onTap,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool focused;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: active
              ? const LinearGradient(colors: [_kFavViolet, Color(0xFF4B2BD0)])
              : null,
          color: active ? null : Colors.white.withValues(alpha: .07),
          border: Border.all(
            width: focused ? 2 : 1,
            color: focused
                ? Colors.white
                : active
                ? const Color(0xFFB79CFF)
                : Colors.white.withValues(alpha: .22),
          ),
          boxShadow: active || focused
              ? [
                  BoxShadow(
                    color: _kFavViolet.withValues(alpha: focused ? .7 : .5),
                    blurRadius: focused ? 18 : 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sidebar tile ────────────────────────────────────────────────────────────

class _FavSectionTile extends StatelessWidget {
  const _FavSectionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.focused,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 46,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: selected
              ? const LinearGradient(colors: [_kFavBlue, _kFavViolet])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: .06),
          border: Border.all(
            width: focused ? 2 : 1,
            color: focused
                ? Colors.white
                : selected
                ? Colors.white.withValues(alpha: .55)
                : Colors.white.withValues(alpha: .08),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kFavBlue.withValues(alpha: focused ? .75 : .45),
                    blurRadius: focused ? 20 : 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: Colors.white),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid / list toggle ──────────────────────────────────────────────────────

class _FavViewToggle extends StatelessWidget {
  const _FavViewToggle({
    required this.listMode,
    required this.focusedIndex,
    required this.onChanged,
  });

  final bool listMode;
  final int? focusedIndex;
  final ValueChanged<bool> onChanged;

  Widget _button(int index, IconData icon) {
    final active = (index == 1) == listMode;
    final focused = focusedIndex == index;
    return GestureDetector(
      onTap: () => onChanged(index == 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 44,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: active
              ? const LinearGradient(colors: [_kFavViolet, Color(0xFF4B2BD0)])
              : null,
          border: Border.all(
            width: focused ? 2 : 1,
            color: focused
                ? Colors.white
                : active
                ? const Color(0xFFB79CFF)
                : Colors.transparent,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: _kFavViolet.withValues(alpha: .7),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(0, Icons.grid_view_rounded),
          _button(1, Icons.format_list_bulleted_rounded),
        ],
      ),
    );
  }
}

// ─── Cards ───────────────────────────────────────────────────────────────────

String _favBadge(_FavEntry entry) {
  if (entry.watch != null && entry.kind != _FavKind.live) return 'RESUME';
  return switch (entry.kind) {
    _FavKind.live => 'LIVE',
    _FavKind.movie => 'MOVIE',
    _FavKind.series => 'SERIES',
  };
}

Color _favBadgeColor(_FavEntry entry) =>
    entry.kind == _FavKind.live ? _kFavLive : _kFavBlue;

IconData _favFallbackIcon(_FavKind kind) => switch (kind) {
  _FavKind.live => Icons.live_tv_rounded,
  _FavKind.movie => Icons.local_movies_rounded,
  _FavKind.series => Icons.movie_creation_rounded,
};

class _FavBadgeChip extends StatelessWidget {
  const _FavBadgeChip({required this.entry});

  final _FavEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: _favBadgeColor(entry),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: .35)),
      ),
      child: Text(
        _favBadge(entry),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

/// Corner star: saved favourites only, not watch-history rows.
class _FavStarCorner extends StatelessWidget {
  const _FavStarCorner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kFavViolet, Color(0xFF4B2BD0)]),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(13),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({
    required this.entry,
    required this.poster,
    required this.selected,
    required this.focused,
    required this.onTap,
    required this.onLongPress,
  });

  final _FavEntry entry;

  /// Portrait poster grid (Movies, Series) rather than landscape tiles.
  final bool poster;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final image = entry.image ?? '';
    final isLive = entry.kind == _FavKind.live;
    final progress = entry.progress;

    Widget art;
    if (image.isEmpty) {
      art = Center(
        child: Icon(
          _favFallbackIcon(entry.kind),
          color: Colors.white.withValues(alpha: .5),
          size: 34,
        ),
      );
    } else {
      art = CachedNetworkImage(
        imageUrl: image,
        // Channel logos are shown whole; posters fill the tile.
        fit: isLive ? BoxFit.contain : BoxFit.cover,
        memCacheWidth: isLive ? 260 : 320,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => Center(
          child: Icon(
            _favFallbackIcon(entry.kind),
            color: Colors.white.withValues(alpha: .5),
            size: 34,
          ),
        ),
      );
    }

    final Widget body;
    if (isLive) {
      // Logo on top, name, LIVE chip: the landscape tile of the design.
      body = Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
        child: LayoutBuilder(
          builder: (context, box) {
            return Column(
              children: [
                Expanded(flex: 5, child: Center(child: art)),
                Flexible(
                  flex: 5,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: box.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            entry.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _FavBadgeChip(entry: entry),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          art,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .86),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: poster ? 11.5 : 13.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _FavBadgeChip(entry: entry),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: focused ? 2.2 : 1.2,
              color: focused
                  ? Colors.white
                  : selected
                  ? const Color(0xFFB79CFF).withValues(alpha: .8)
                  : Colors.white.withValues(alpha: .26),
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: _kFavViolet.withValues(alpha: .75),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B2552),
                        Color(0xFF0E1430),
                        Color(0xFF0A0E22),
                      ],
                    ),
                  ),
                ),
                body,
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: .18),
                      valueColor: const AlwaysStoppedAnimation(_kFavStar),
                    ),
                  ),
                if (entry.favorite != null)
                  const Positioned(top: 0, right: 0, child: _FavStarCorner()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavListRow extends StatelessWidget {
  const _FavListRow({
    required this.entry,
    required this.selected,
    required this.focused,
    required this.onTap,
    required this.onLongPress,
  });

  final _FavEntry entry;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final image = entry.image ?? '';
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? _kFavViolet.withValues(alpha: .22)
              : Colors.white.withValues(alpha: .06),
          border: Border.all(
            width: focused ? 2 : 1,
            color: focused
                ? Colors.white
                : selected
                ? const Color(0xFFB79CFF).withValues(alpha: .7)
                : Colors.white.withValues(alpha: .10),
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: _kFavViolet.withValues(alpha: .6),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 34,
              child: image.isEmpty
                  ? Icon(
                      _favFallbackIcon(entry.kind),
                      color: Colors.white54,
                      size: 20,
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.contain,
                      memCacheWidth: 160,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => Icon(
                        _favFallbackIcon(entry.kind),
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _FavBadgeChip(entry: entry),
            if (entry.favorite != null) ...[
              const SizedBox(width: 10),
              const Icon(Icons.star_rounded, color: _kFavStar, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Empty-state jump tile ───────────────────────────────────────────────────

class _FavJumpTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FavJumpTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_FavJumpTile> createState() => _FavJumpTileState();
}

class _FavJumpTileState extends State<_FavJumpTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.gameButtonA) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  width: _focused ? 2 : 1,
                  color: _focused
                      ? kColorFocus
                      : Colors.white.withValues(alpha: 0.10),
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: kColorPrimary.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(widget.icon, color: kColorPrimary, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
