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
        if (_appbarIdx == 0) Get.back();
      } else if (k == LogicalKeyboardKey.escape) {
        Get.back();
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
        setState(() => _panel = 2);
      } else if (k == LogicalKeyboardKey.escape) {
        Get.back();
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
      if (k == LogicalKeyboardKey.escape) {
        Get.back();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleSelect() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;
    final favState = context.read<FavoritesCubit>().state;

    if (_tabIdx == 0) {
      if (_liveIdx >= favState.lives.length) return;
      final ch = favState.lives[_liveIdx];
      final link =
          '${authState.user.serverInfo!.serverUrl}/${authState.user.userInfo!.username}/${authState.user.userInfo!.password}/${ch.streamId}';
      Get.to(
        () => LivePlayerScreen(
          link: link,
          title: ch.name ?? '',
          streamIcon: ch.streamIcon,
        ),
      );
    } else if (_tabIdx == 1) {
      if (_movieIdx >= favState.movies.length) return;
      final m = favState.movies[_movieIdx];
      Get.to(() => MovieContent(channelMovie: m, videoId: m.streamId ?? ''));
    } else {
      if (_serieIdx >= favState.series.length) return;
      final s = favState.series[_serieIdx];
      Get.to(() => SerieContent(channelSerie: s, videoId: s.seriesId ?? ''));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    icon: FontAwesomeIcons.heart,
                    onBack: Get.back,
                    focusedIndex: _appbarActive ? _appbarIdx : null,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left sidebar ────────────────────────────────────
                    // SafeArea(
                    //   right: false,
                    //   bottom: false,
                    //   top: false,
                    //   child: SizedBox(width: 190, child: _buildSidebar()),
                    // ),
                    SizedBox(width: 190, child: _buildSidebar()),
                    Container(width: 1, color: kColorCardLight),
                    // ── Content panel ───────────────────────────────────
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
    const labels = ['Live TV', 'Movies', 'Series'];
    const icons = [
      FontAwesomeIcons.tv,
      FontAwesomeIcons.film,
      FontAwesomeIcons.clapperboard,
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
        if (authState is! AuthSuccess) return const SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, favState) {
            if (_tabIdx == 0) {
              final items = favState.lives;
              if (items.isEmpty)
                return _emptyState(
                  FontAwesomeIcons.tv,
                  'No favourite channels yet',
                );
              return ListView.builder(
                controller: _liveScroll,
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
                      final link =
                          '${authState.user.serverInfo!.serverUrl}/${authState.user.userInfo!.username}/${authState.user.userInfo!.password}/${items[i].streamId}';
                      Get.to(
                        () => LivePlayerScreen(
                          link: link,
                          title: items[i].name ?? '',
                          streamIcon: items[i].streamIcon,
                        ),
                      );
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
                                ? FontAwesomeIcons.play
                                : FontAwesomeIcons.tv,
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
                  FontAwesomeIcons.film,
                  'No favourite movies yet',
                );
              return GridView.builder(
                controller: _movieScroll,
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
                      Get.to(
                        () => MovieContent(
                          channelMovie: items[i],
                          videoId: items[i].streamId ?? '',
                        ),
                      );
                    },
                    child: _FavPosterItem(
                      image: items[i].streamIcon,
                      title: items[i].name ?? '',
                      isSelected: isSelected,
                      isFocused: isFocused,
                      fallbackIcon: FontAwesomeIcons.film,
                    ),
                  );
                },
              );
            }

            // Series
            final items = favState.series;
            if (items.isEmpty)
              return _emptyState(
                FontAwesomeIcons.clapperboard,
                'No favourite series yet',
              );
            return GridView.builder(
              controller: _serieScroll,
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
                    fallbackIcon: FontAwesomeIcons.clapperboard,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kColorPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: kColorPrimary.withValues(alpha: 0.2)),
            ),
            child: Icon(
              icon,
              size: 32,
              color: kColorPrimary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
            ),
          ),
        ],
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
                  child: const Icon(
                    FontAwesomeIcons.play,
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
