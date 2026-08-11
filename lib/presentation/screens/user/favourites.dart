part of '../screens.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  // panel: 1 = sidebar, 2 = content
  int _panel = 1;
  int _tabIdx = 0; // 0=Live, 1=Movies, 2=Series

  bool _appbarActive = false;
  int _appbarIdx = 0;
  // back=0 only, no search
  static const int _appbarBtnMax = 0;

  // Content focus index per tab
  int _liveIdx = 0;
  int _movieIdx = 0;
  int _serieIdx = 0;

  // Grid columns per tab (live = 1 column list)
  static const _gridCols = [1, 5, 5];

  final _liveScroll = ScrollController();
  final _movieScroll = ScrollController();
  final _serieScroll = ScrollController();
  final _navFocus = FocusNode();

  @override
  void dispose() {
    _liveScroll.dispose();
    _movieScroll.dispose();
    _serieScroll.dispose();
    _navFocus.dispose();
    super.dispose();
  }

  int get _cols => _gridCols[_tabIdx];

  int get _currentIdx => [_liveIdx, _movieIdx, _serieIdx][_tabIdx];

  void _setCurrentIdx(int v) {
    setState(() {
      if (_tabIdx == 0)
        _liveIdx = v;
      else if (_tabIdx == 1)
        _movieIdx = v;
      else
        _serieIdx = v;
    });
  }

  int _getCount() {
    final s = context.read<FavoritesCubit>().state;
    if (_tabIdx == 0) return s.lives.length;
    if (_tabIdx == 1) return s.movies.length;
    return s.series.length;
  }

  ScrollController get _activeScroll =>
      [_liveScroll, _movieScroll, _serieScroll][_tabIdx];

  void _scrollContentTo(int idx) {
    final sc = _activeScroll;
    if (!sc.hasClients) return;
    final row = idx ~/ _cols;
    final itemH = _tabIdx == 0 ? 60.0 : 190.0;
    final target = (row * itemH).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// Same TV Back contract as CatchUp/Settings: handle goBack + escape, never
  /// swallow goBack with [KeyEventResult.handled] without popping to the shell.
  bool _isBackKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack;

  void _popToShell() {
    // Guard against double-pop (Focus goBack + system Back in one frame)
    // which finishes MainActivity → Google TV Home.
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Get.back();
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // ── Appbar ─────────────────────────────────────────────────────────────
    if (_appbarActive) {
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() => _appbarActive = false);
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        if (_appbarIdx > 0) setState(() => _appbarIdx--);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        if (_appbarIdx < _appbarBtnMax) setState(() => _appbarIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        if (_appbarIdx == 0) _popToShell();
      } else if (_isBackKey(k)) {
        _popToShell();
      }
      return KeyEventResult.handled;
    }

    // ── Sidebar ────────────────────────────────────────────────────────────
    if (_panel == 1) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_tabIdx > 0) {
          setState(() => _tabIdx--);
        } else {
          setState(() {
            _appbarActive = true;
            _appbarIdx = 0;
          });
        }
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_tabIdx < 2) setState(() => _tabIdx++);
      } else if (k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        // Stay on sidebar when section is empty — avoids a focus trap with
        // no selectable items and no visible focus ring.
        if (_getCount() > 0) {
          setState(() => _panel = 2);
        }
      } else if (_isBackKey(k)) {
        _popToShell();
      }
      return KeyEventResult.handled;
    }

    // ── Content ────────────────────────────────────────────────────────────
    if (_panel == 2) {
      final idx = _currentIdx;
      final cols = _cols;
      final count = _getCount();

      if (k == LogicalKeyboardKey.arrowLeft) {
        if (idx % cols == 0) {
          setState(() => _panel = 1);
        } else {
          _setCurrentIdx(idx - 1);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        if (idx < count - 1 && (idx + 1) % cols != 0) {
          _setCurrentIdx(idx + 1);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (idx < cols) {
          setState(() => _panel = 1);
        } else {
          _setCurrentIdx(idx - cols);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        if (idx + cols < count) {
          _setCurrentIdx(idx + cols);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _handleSelect();
        return KeyEventResult.handled;
      }
      if (_isBackKey(k)) {
        _popToShell();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_isBackKey(k)) {
      _popToShell();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

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

  void _handleSelect() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;
    final favState = context.read<FavoritesCubit>().state;

    if (_tabIdx == 0) {
      if (_liveIdx >= favState.lives.length) return;
      final ch = favState.lives[_liveIdx];
      _playLiveFavorite(ch);
    } else if (_tabIdx == 1) {
      if (_movieIdx >= favState.movies.length) return;
      final m = favState.movies[_movieIdx];
      if (isTv(context)) {
        Get.to(() => MovieContent(channelMovie: m, videoId: m.streamId ?? ''));
      } else {
        Get.to(
          () => MobileDetailScreen(
            movie: m,
            onPlayTap: () {
              Get.back();
              _playMovieMobile(m);
            },
          ),
        );
      }
    } else {
      if (_serieIdx >= favState.series.length) return;
      final s = favState.series[_serieIdx];
      Get.to(() => SerieContent(channelSerie: s, videoId: s.seriesId ?? ''));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Match Settings: Focus-only Back (no PopScope). PopScope(canPop:false)
    // + Focus goBack both calling Get.back() double-popped → Google TV Home.
    return Focus(
      focusNode: _navFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Ink(
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
                    focusedIndex: _appbarActive ? _appbarIdx : null,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 190, child: _buildSidebar()),
                    Container(width: 1, color: kColorCardLight),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final fav = context.watch<FavoritesCubit>().state;
    final labels = [
      'Live TV (${fav.lives.length})',
      'Movies (${fav.movies.length})',
      'Series (${fav.series.length})',
    ];
    final icons = [
      FontAwesomeIcons.tv.data,
      FontAwesomeIcons.film.data,
      FontAwesomeIcons.clapperboard.data,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Text(
            'SECTIONS',
            style: Get.textTheme.bodySmall!.copyWith(
              color: kColorHint,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        ...List.generate(3, (i) {
          final isSelected = _tabIdx == i;
          final isFocused = isSelected && _panel == 1;
          return GestureDetector(
            onTap: () => setState(() {
              _tabIdx = i;
              _panel = 2;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? kColorPrimary.withValues(alpha: .18)
                    : kColorCardLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused
                      ? kColorFocus
                      : isSelected
                      ? kColorPrimary.withValues(alpha: .5)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: kColorFocus.withValues(alpha: .25),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    icons[i],
                    size: 14,
                    color: isSelected ? kColorPrimary : Colors.white38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels[i],
                      style: Get.textTheme.bodySmall!.copyWith(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: kColorFocus,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContent() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, favState) {
            if (_tabIdx == 0) {
              final items = favState.lives;
              if (items.isEmpty)
                return _emptyState(
                  FontAwesomeIcons.tv.data,
                  'No favourite channels yet',
                );
              return ListView.builder(
                controller: _liveScroll,
                cacheExtent: 350.0,
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final isSelected = i == _liveIdx;
                  final isFocused = isSelected && _panel == 2;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _liveIdx = i;
                        _panel = 2;
                      });
                      _playLiveFavorite(items[i]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kColorPrimary.withValues(alpha: .18)
                            : kColorCardLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused
                              ? kColorFocus
                              : isSelected
                              ? kColorPrimary.withValues(alpha: .5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: kColorFocus.withValues(alpha: .3),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isFocused
                                ? FontAwesomeIcons.play.data
                                : FontAwesomeIcons.tv.data,
                            size: 13,
                            color: isSelected ? kColorPrimary : Colors.white38,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              items[i].name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Get.textTheme.bodySmall!.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            if (_tabIdx == 1) {
              final items = favState.movies;
              if (items.isEmpty)
                return _emptyState(
                  FontAwesomeIcons.film.data,
                  'No favourite movies yet',
                );
              return GridView.builder(
                controller: _movieScroll,
                cacheExtent: 350.0,
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .7,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final isSelected = i == _movieIdx;
                  final isFocused = isSelected && _panel == 2;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _movieIdx = i;
                        _panel = 2;
                      });
                      if (isTv(context)) {
                        Get.to(
                          () => MovieContent(
                            channelMovie: items[i],
                            videoId: items[i].streamId ?? '',
                          ),
                        );
                      } else {
                        Get.to(
                          () => MobileDetailScreen(
                            movie: items[i],
                            onPlayTap: () {
                              Get.back();
                              _playMovieMobile(items[i]);
                            },
                          ),
                        );
                      }
                    },
                    child: _FavPosterItem(
                      image: items[i].streamIcon,
                      title: items[i].name ?? '',
                      isSelected: isSelected,
                      isFocused: isFocused,
                      fallbackIcon: FontAwesomeIcons.film.data,
                    ),
                  );
                },
              );
            }

            // Series
            final items = favState.series;
            if (items.isEmpty)
              return _emptyState(
                FontAwesomeIcons.clapperboard.data,
                'No favourite series yet',
              );
            return GridView.builder(
              controller: _serieScroll,
              cacheExtent: 350.0,
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .7,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final isSelected = i == _serieIdx;
                final isFocused = isSelected && _panel == 2;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _serieIdx = i;
                      _panel = 2;
                    });
                    Get.to(
                      () => SerieContent(
                        channelSerie: items[i],
                        videoId: items[i].seriesId ?? '',
                      ),
                    );
                  },
                  child: _FavPosterItem(
                    image: items[i].cover,
                    title: items[i].name ?? '',
                    isSelected: isSelected,
                    isFocused: isFocused,
                    fallbackIcon: FontAwesomeIcons.clapperboard.data,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String label) {
    WatchingState? watch;
    try {
      watch = context.read<WatchingCubit>().state;
    } catch (_) {}
    final recs = <WatchingModel>[
      ...?watch?.live,
      ...?watch?.movies,
      ...?watch?.series,
    ].take(8).toList();

    return TvBrandedEmpty(
      icon: Icons.favorite_rounded,
      title: label,
      subtitle:
          'Add items from Live TV, Movies, or Series. Build your list for quick access anytime.',
      extra: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'From your watch history',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final w = recs[i];
                  return SizedBox(
                    width: 168,
                    child: TvChannelCard(
                      stream: TvStreamRecord(
                        title: TitleNormalizer.parse(w.title).displayTitle,
                        subtitle: 'Recently watched',
                        streamUrl: w.stream.isNotEmpty ? w.stream : w.streamId,
                        imageUrl: w.image.isNotEmpty ? w.image : null,
                      ),
                      onSelected: () {
                        if (w.stream.isNotEmpty) {
                          Get.to(
                            () => LivePlayerScreen(
                              link: w.stream,
                              title: w.title,
                              streamId: w.streamId,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _playMovieMobile(ChannelMovie movie) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;
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

// ─── Poster card (Movies / Series) ─────────────────────────────────────────────

class _FavPosterItem extends StatelessWidget {
  const _FavPosterItem({
    required this.image,
    required this.title,
    required this.isSelected,
    required this.isFocused,
    required this.fallbackIcon,
  });

  final String? image;
  final String title;
  final bool isSelected;
  final bool isFocused;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: kColorCardLight,
        border: Border.all(
          color: isFocused
              ? kColorFocus
              : isSelected
              ? kColorPrimary.withValues(alpha: .5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: kColorFocus.withValues(alpha: .4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: image ?? '',
              fit: BoxFit.cover,
              memCacheWidth: 300,
              placeholder: (_, __) => Container(
                color: kColorCardDark,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: kColorPrimary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: kColorCardDark,
                child: Center(
                  child: Icon(fallbackIcon, color: kColorHint, size: 28),
                ),
              ),
            ),
            // gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .75),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (isFocused)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: kColorFocus,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(FontAwesomeIcons.play.data,
                    color: Colors.white,
                    size: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
