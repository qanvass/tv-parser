part of '../screens.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  int _tabIdx = 0;

  // panel: 0 = tabs row focused, 1 = content
  int _panel = 0;

  bool _appbarActive = false;
  int _appbarIdx = 0;
  // back=0 only, no search
  static const int _appbarBtnMax = 0;

  final _navFocus = FocusNode();

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // ── Appbar active ──────────────────────────────────────────────────────
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

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_panel == 1) {
        setState(() => _panel = 0);
      } else {
        setState(() { _appbarActive = true; _appbarIdx = 0; });
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      if (_panel == 0) setState(() => _panel = 1);
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_panel == 0 && _tabIdx > 0) setState(() => _tabIdx--);
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowRight) {
      if (_panel == 0 && _tabIdx < 2) setState(() => _tabIdx++);
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_panel == 0) setState(() => _panel = 1);
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: _buildTabs(),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tabIdx,
                  children: const [
                    _FavLivePage(),
                    _FavMoviesPage(),
                    _FavSeriesPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['Live TV', 'Movies', 'Series'];
    const icons = [
      FontAwesomeIcons.tv,
      FontAwesomeIcons.film,
      FontAwesomeIcons.clapperboard,
    ];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(3, (i) {
          final isSelected = _tabIdx == i;
          final isFocused = isSelected && _panel == 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _tabIdx = i;
                _panel = 1;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isFocused
                      ? kColorFocus
                      : isSelected
                      ? kColorPrimary.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? kColorFocus
                        : isSelected
                        ? kColorPrimary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: kColorFocus.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[i],
                      size: 13,
                      color: isFocused
                          ? Colors.white
                          : isSelected
                          ? kColorPrimary
                          : Colors.white38,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: isFocused || isSelected
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Live Tab ──────────────────────────────────────────────────────────────────

class _FavLivePage extends StatelessWidget {
  const _FavLivePage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        final userAuth = authState.user;
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            final lives = state.lives;
            if (lives.isEmpty) {
              return const _FavEmptyState(
                icon: FontAwesomeIcons.tv,
                label: 'No favourite channels yet',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 5,
              ),
              itemCount: lives.length,
              itemBuilder: (_, i) => CardLiveItem(
                title: lives[i].name ?? '',
                onTap: () {
                  final link =
                      '${userAuth.serverInfo!.serverUrl}/${userAuth.userInfo!.username}/${userAuth.userInfo!.password}/${lives[i].streamId}';
                  Get.to(
                    () => FullVideoScreen(
                      isLive: true,
                      link: link,
                      title: lives[i].name ?? '',
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Movies Tab ────────────────────────────────────────────────────────────────

class _FavMoviesPage extends StatelessWidget {
  const _FavMoviesPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            final movies = state.movies;
            if (movies.isEmpty) {
              return const _FavEmptyState(
                icon: FontAwesomeIcons.film,
                label: 'No favourite movies yet',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .7,
              ),
              itemCount: movies.length,
              itemBuilder: (_, i) => CardChannelMovieItem(
                title: movies[i].name ?? '',
                image: movies[i].streamIcon,
                onTap: () => Get.to(
                  () => MovieContent(
                    channelMovie: movies[i],
                    videoId: movies[i].streamId ?? '',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Series Tab ────────────────────────────────────────────────────────────────

class _FavSeriesPage extends StatelessWidget {
  const _FavSeriesPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            final series = state.series;
            if (series.isEmpty) {
              return const _FavEmptyState(
                icon: FontAwesomeIcons.clapperboard,
                label: 'No favourite series yet',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .7,
              ),
              itemCount: series.length,
              itemBuilder: (_, i) => CardChannelMovieItem(
                title: series[i].name ?? '',
                image: series[i].cover,
                onTap: () => Get.to(
                  () => SerieContent(
                    channelSerie: series[i],
                    videoId: series[i].seriesId ?? '',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _FavEmptyState extends StatelessWidget {
  const _FavEmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kColorPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: kColorPrimary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 32, color: kColorPrimary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
