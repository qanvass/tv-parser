part of 'screens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FavoritesCubit>().initialData();
    context.read<WatchingCubit>().initialData();
  }

  @override
  Widget build(BuildContext context) {
    return isTv(context) ? const _HomeTvLayout() : const _HomeMobileLayout();
  }
}

// ─── TV LAYOUT ────────────────────────────────────────────────────────────────
// Simple card grid — same look as original but with working D-pad focus.
//
// Layout:
//   Row 0 → [Live TV]  [Movies]  [Series]      (items 0,1,2)
//   Row 1 → [Favorites] [Catch Up] [Settings]  (items 3,4,5)
//
// Remote:  ◄ ► move within row  |  ▼▲ switch rows  |  OK/Enter activates

class _HomeTvLayout extends StatefulWidget {
  const _HomeTvLayout({super.key});

  @override
  State<_HomeTvLayout> createState() => _HomeTvLayoutState();
}

class _HomeTvLayoutState extends State<_HomeTvLayout> {
  // 0-2 = top row cards, 3-5 = bottom row buttons
  int _focused = 0;
  final FocusNode _navFocus = FocusNode();

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight) {
      final max = _focused < 3 ? 2 : 5;
      if (_focused < max) setState(() => _focused++);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final min = _focused < 3 ? 0 : 3;
      if (_focused > min) setState(() => _focused--);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _focused < 3) {
      setState(() => _focused = 3);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _focused >= 3) {
      setState(() => _focused = 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _activate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activate() {
    switch (_focused) {
      case 0:
        Get.toNamed(screenLiveCategories);
      case 1:
        Get.toNamed(screenMovieCategories);
      case 2:
        Get.toNamed(screenSeriesCategories);
      case 3:
        Get.toNamed(screenFavourite);
      case 4:
        Get.toNamed(screenCatchUp);
      case 5:
        Get.toNamed(screenSettings);
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
          width: double.infinity,
          height: double.infinity,
          decoration: kDecorBackground,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            children: [
              // ── App bar ──────────────────────────────────────────────
              const WelcomeAppBar(),
              const SizedBox(height: 32),

              // ── Main category cards ──────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BlocBuilder<LiveCatyBloc, LiveCatyState>(
                        builder: (context, state) {
                          final count = state is LiveCatySuccess
                              ? state.categories.length
                              : 0;
                          return _TvCard(
                            title: 'Live TV',
                            subtitle: '$count Channels',
                            icon: kIconLive,
                            isFocused: _focused == 0,
                            onTap: () => Get.toNamed(screenLiveCategories),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: BlocBuilder<MovieCatyBloc, MovieCatyState>(
                        builder: (context, state) {
                          final count = state is MovieCatySuccess
                              ? state.categories.length
                              : 0;
                          return _TvCard(
                            title: 'Movies',
                            subtitle: '$count Movies',
                            icon: kIconMovies,
                            isFocused: _focused == 1,
                            onTap: () => Get.toNamed(screenMovieCategories),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: BlocBuilder<SeriesCatyBloc, SeriesCatyState>(
                        builder: (context, state) {
                          final count = state is SeriesCatySuccess
                              ? state.categories.length
                              : 0;
                          return _TvCard(
                            title: 'Series',
                            subtitle: '$count Series',
                            icon: kIconSeries,
                            isFocused: _focused == 2,
                            onTap: () => Get.toNamed(screenSeriesCategories),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Secondary action buttons ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TvActionBtn(
                    title: 'Favourites',
                    icon: FontAwesomeIcons.heart,
                    isFocused: _focused == 3,
                    onTap: () => Get.toNamed(screenFavourite),
                  ),
                  const SizedBox(width: 20),
                  _TvActionBtn(
                    title: 'Catch Up',
                    icon: FontAwesomeIcons.rotate,
                    isFocused: _focused == 4,
                    onTap: () => Get.toNamed(screenCatchUp),
                  ),
                  const SizedBox(width: 20),
                  _TvActionBtn(
                    title: 'Settings',
                    icon: FontAwesomeIcons.gear,
                    isFocused: _focused == 5,
                    onTap: () => Get.toNamed(screenSettings),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TV Card ──────────────────────────────────────────────────────────────────

class _TvCard extends StatelessWidget {
  const _TvCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isFocused,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String icon;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isFocused
              ? kColorPrimary.withValues(alpha: .18)
              : kColorCardLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isFocused ? kColorFocus : Colors.transparent,
            width: 3,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .45),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isFocused ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Image.asset(icon, width: 8.w, height: 8.w),
            ),
            SizedBox(height: 3.h),
            Text(
              title,
              style: Get.textTheme.displaySmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: isFocused ? kColorFocus : Colors.white,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              '◍ $subtitle',
              style: Get.textTheme.titleSmall!.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TV Action Button ─────────────────────────────────────────────────────────

class _TvActionBtn extends StatelessWidget {
  const _TvActionBtn({
    required this.title,
    required this.icon,
    required this.isFocused,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: isFocused ? kColorPrimary : kColorCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused ? kColorFocus : kColorCardDark,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .4),
                    blurRadius: 14,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isFocused ? Colors.white : kColorPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Get.textTheme.titleSmall!.copyWith(
                color: isFocused ? Colors.white : Colors.white70,
                fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MOBILE LAYOUT ────────────────────────────────────────────────────────────

class _HomeMobileLayout extends StatefulWidget {
  const _HomeMobileLayout({super.key});

  @override
  State<_HomeMobileLayout> createState() => _HomeMobileLayoutState();
}

class _HomeMobileLayoutState extends State<_HomeMobileLayout> {
  int _tabIndex = 0;
  final _liveSearch = TextEditingController();
  final _moviesSearch = TextEditingController();
  final _seriesSearch = TextEditingController();
  String _liveKey = '';
  String _moviesKey = '';
  String _seriesKey = '';

  @override
  void dispose() {
    _liveSearch.dispose();
    _moviesSearch.dispose();
    _seriesSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBackDark,
      body: Ink(
        decoration: kDecorBackground,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: const WelcomeAppBar(),
              ),
              if (_tabIndex != 3) _buildSearchBar(),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _LiveCategoriesTab(searchKey: _liveKey),
                    _MovieCategoriesTab(searchKey: _moviesKey),
                    _SeriesCategoriesTab(searchKey: _seriesKey),
                    const _FavoritesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _HomeBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  Widget _buildSearchBar() {
    final controllers = [_liveSearch, _moviesSearch, _seriesSearch];
    final callbacks = [
      (String v) => setState(() => _liveKey = v.toLowerCase()),
      (String v) => setState(() => _moviesKey = v.toLowerCase()),
      (String v) => setState(() => _seriesKey = v.toLowerCase()),
    ];
    final hints = [
      'Search live channels...',
      'Search movies...',
      'Search series...',
    ];
    return HomeSearchBar(
      controller: controllers[_tabIndex],
      onChanged: callbacks[_tabIndex],
      hint: hints[_tabIndex],
    );
  }
}

// ─── BOTTOM NAVIGATION BAR ────────────────────────────────────────────────────

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: kColorBackDark,
      selectedItemColor: kColorPrimary,
      unselectedItemColor: kColorHint,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: Get.textTheme.bodySmall!.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 11.sp,
      ),
      unselectedLabelStyle: Get.textTheme.bodySmall!.copyWith(
        fontSize: 10.sp,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.tv, size: 20),
          label: 'Live TV',
        ),
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.film, size: 20),
          label: 'Movies',
        ),
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.clapperboard, size: 20),
          label: 'Series',
        ),
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.heart, size: 20),
          label: 'Favorites',
        ),
      ],
    );
  }
}

// ─── LIVE CATEGORIES TAB ──────────────────────────────────────────────────────

class _LiveCategoriesTab extends StatelessWidget {
  const _LiveCategoriesTab({this.searchKey = ''});
  final String searchKey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingState) {
        final isDemo = settingState.isDemo;
        return BlocBuilder<LiveCatyBloc, LiveCatyState>(
          builder: (context, state) {
            if (state is LiveCatyLoading) return const _LoadingState();

            final List<CategoryModel> all = state is LiveCatySuccess
                ? state.categories
                : isDemo
                ? [
                    CategoryModel(
                      categoryName: 'Demo Channel 1',
                      categoryId: '1',
                    ),
                    CategoryModel(
                      categoryName: 'Demo Channel 2',
                      categoryId: '2',
                    ),
                  ]
                : [];

            final items = searchKey.isNotEmpty
                ? all
                    .where(
                      (c) =>
                          c.categoryName!.toLowerCase().contains(searchKey),
                    )
                    .toList()
                : all;

            if (items.isEmpty) return const _EmptyState(label: 'No channels');

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 4,
              ),
              itemBuilder: (_, i) => CardLiveItem(
                title: items[i].categoryName ?? '',
                onTap: () {
                  if (isDemo) {
                    Get.to(
                      () => const FullVideoScreen(
                        title: 'Channel',
                        link: kDemoUrl,
                        isLive: true,
                      ),
                    );
                  } else {
                    Get.toNamed(screenLiveCategories);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── MOVIES CATEGORIES TAB ────────────────────────────────────────────────────

class _MovieCategoriesTab extends StatelessWidget {
  const _MovieCategoriesTab({this.searchKey = ''});
  final String searchKey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingState) {
        final isDemo = settingState.isDemo;
        return BlocBuilder<MovieCatyBloc, MovieCatyState>(
          builder: (context, state) {
            if (state is MovieCatyLoading) return const _LoadingState();

            final List<CategoryModel> all = state is MovieCatySuccess
                ? state.categories
                : isDemo
                ? [CategoryModel(categoryId: '1', categoryName: 'Demo Movies')]
                : [];

            final items = searchKey.isNotEmpty
                ? all
                    .where(
                      (c) =>
                          c.categoryName!.toLowerCase().contains(searchKey),
                    )
                    .toList()
                : all;

            if (items.isEmpty) return const _EmptyState(label: 'No movies');

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 4,
              ),
              itemBuilder: (_, i) => CardLiveItem(
                title: items[i].categoryName ?? '',
                onTap: () {
                  if (isDemo) {
                    Get.to(
                      () => const FullVideoScreen(
                        title: 'Movie',
                        link: kDemoUrl,
                        isLive: true,
                      ),
                    );
                  } else {
                    Get.to(
                      () => MovieChannels(catyId: items[i].categoryId ?? ''),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── SERIES CATEGORIES TAB ────────────────────────────────────────────────────

class _SeriesCategoriesTab extends StatelessWidget {
  const _SeriesCategoriesTab({this.searchKey = ''});
  final String searchKey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingState) {
        final isDemo = settingState.isDemo;
        return BlocBuilder<SeriesCatyBloc, SeriesCatyState>(
          builder: (context, state) {
            if (state is SeriesCatyLoading) return const _LoadingState();

            final List<CategoryModel> all = state is SeriesCatySuccess
                ? state.categories
                : isDemo
                ? [
                    CategoryModel(
                      categoryId: '1',
                      categoryName: 'Demo Series',
                    ),
                  ]
                : [];

            final items = searchKey.isNotEmpty
                ? all
                    .where(
                      (c) =>
                          c.categoryName!.toLowerCase().contains(searchKey),
                    )
                    .toList()
                : all;

            if (items.isEmpty) return const _EmptyState(label: 'No series');

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 4,
              ),
              itemBuilder: (_, i) => CardLiveItem(
                title: items[i].categoryName ?? '',
                onTap: () {
                  if (isDemo) {
                    Get.to(
                      () => const FullVideoScreen(
                        title: 'Series',
                        link: kDemoUrl,
                        isLive: true,
                      ),
                    );
                  } else {
                    Get.to(
                      () => SeriesChannels(
                        catyId: items[i].categoryId ?? '',
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── FAVORITES TAB ────────────────────────────────────────────────────────────

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab({super.key});

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  int _subTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kColorCardLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _FavSubTab(
                label: 'Live',
                isSelected: _subTab == 0,
                onTap: () => setState(() => _subTab = 0),
              ),
              _FavSubTab(
                label: 'Movies',
                isSelected: _subTab == 1,
                onTap: () => setState(() => _subTab = 1),
              ),
              _FavSubTab(
                label: 'Series',
                isSelected: _subTab == 2,
                onTap: () => setState(() => _subTab = 2),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _subTab,
            children: [
              _FavLiveList(),
              const _FavMoviesList(cols: 3),
              const _FavSeriesList(cols: 3),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavSubTab extends StatelessWidget {
  const _FavSubTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? kColorPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Get.textTheme.titleSmall!.copyWith(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _FavLiveList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        final userAuth = authState.user;
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            final lives = state.lives;
            if (lives.isEmpty) return const _EmptyState(label: 'No favorites');
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: lives.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 4,
              ),
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

class _FavMoviesList extends StatelessWidget {
  const _FavMoviesList({required this.cols});
  final int cols;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            final movies = state.movies;
            if (movies.isEmpty) return const _EmptyState(label: 'No favorites');
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: movies.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .7,
              ),
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

class _FavSeriesList extends StatelessWidget {
  const _FavSeriesList({required this.cols});
  final int cols;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthSuccess) return const SizedBox();
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            final series = state.series;
            if (series.isEmpty) return const _EmptyState(label: 'No favorites');
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: series.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .7,
              ),
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

// ─── SHARED ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: kColorPrimary));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FontAwesomeIcons.boxOpen, size: 40, color: kColorHint),
            const SizedBox(height: 12),
            Text(
              label,
              style: Get.textTheme.bodyMedium!.copyWith(color: kColorHint),
            ),
          ],
        ),
      );
}
