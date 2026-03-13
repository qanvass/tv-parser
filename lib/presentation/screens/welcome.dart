part of 'screens.dart';

// ─── HOME SCREEN (post-login) ─────────────────────────────────────────────────
// Mobile  → BottomNavigationBar + IndexedStack (Live | Movies | Series | Favorites)
// TV      → Left sidebar + content grid with full D-pad remote support

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _tabIndex = 0;

  // Per-tab search
  final _liveSearch = TextEditingController();
  final _moviesSearch = TextEditingController();
  final _seriesSearch = TextEditingController();
  String _liveKey = '';
  String _moviesKey = '';
  String _seriesKey = '';

  @override
  void initState() {
    super.initState();
    context.read<FavoritesCubit>().initialData();
    context.read<WatchingCubit>().initialData();
  }

  @override
  void dispose() {
    _liveSearch.dispose();
    _moviesSearch.dispose();
    _seriesSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isTv(context)
        ? _HomeTvLayout(
            tabIndex: _tabIndex,
            onTabChange: (i) => setState(() => _tabIndex = i),
            liveKey: _liveKey,
            moviesKey: _moviesKey,
            seriesKey: _seriesKey,
            liveSearch: _liveSearch,
            moviesSearch: _moviesSearch,
            seriesSearch: _seriesSearch,
            onLiveSearch: (v) => setState(() => _liveKey = v.toLowerCase()),
            onMoviesSearch: (v) =>
                setState(() => _moviesKey = v.toLowerCase()),
            onSeriesSearch: (v) =>
                setState(() => _seriesKey = v.toLowerCase()),
          )
        : _HomeMobileLayout(
            tabIndex: _tabIndex,
            onTabChange: (i) => setState(() => _tabIndex = i),
            liveKey: _liveKey,
            moviesKey: _moviesKey,
            seriesKey: _seriesKey,
            liveSearch: _liveSearch,
            moviesSearch: _moviesSearch,
            seriesSearch: _seriesSearch,
            onLiveSearch: (v) => setState(() => _liveKey = v.toLowerCase()),
            onMoviesSearch: (v) =>
                setState(() => _moviesKey = v.toLowerCase()),
            onSeriesSearch: (v) =>
                setState(() => _seriesKey = v.toLowerCase()),
          );
  }
}

// ─── MOBILE LAYOUT ────────────────────────────────────────────────────────────

class _HomeMobileLayout extends StatelessWidget {
  const _HomeMobileLayout({
    required this.tabIndex,
    required this.onTabChange,
    required this.liveKey,
    required this.moviesKey,
    required this.seriesKey,
    required this.liveSearch,
    required this.moviesSearch,
    required this.seriesSearch,
    required this.onLiveSearch,
    required this.onMoviesSearch,
    required this.onSeriesSearch,
  });

  final int tabIndex;
  final ValueChanged<int> onTabChange;
  final String liveKey, moviesKey, seriesKey;
  final TextEditingController liveSearch, moviesSearch, seriesSearch;
  final ValueChanged<String> onLiveSearch, onMoviesSearch, onSeriesSearch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBackDark,
      body: Ink(
        decoration: kDecorBackground,
        child: SafeArea(
          child: Column(
            children: [
              // ── App Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: const WelcomeAppBar(),
              ),

              // ── Search bar (hidden on Favorites tab) ──
              if (tabIndex != 3)
                _buildSearchBar(context),

              // ── Tab content ──
              Expanded(
                child: IndexedStack(
                  index: tabIndex,
                  children: [
                    _LiveCategoriesTab(searchKey: liveKey),
                    _MovieCategoriesTab(searchKey: moviesKey),
                    _SeriesCategoriesTab(searchKey: seriesKey),
                    const _FavoritesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: _HomeBottomNav(
        currentIndex: tabIndex,
        onTap: onTabChange,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final controllers = [liveSearch, moviesSearch, seriesSearch];
    final callbacks = [onLiveSearch, onMoviesSearch, onSeriesSearch];
    final hints = ['Search live channels...', 'Search movies...', 'Search series...'];

    return HomeSearchBar(
      controller: controllers[tabIndex],
      onChanged: callbacks[tabIndex],
      hint: hints[tabIndex],
    );
  }
}

// ─── TV LAYOUT ────────────────────────────────────────────────────────────────

class _HomeTvLayout extends StatelessWidget {
  const _HomeTvLayout({
    required this.tabIndex,
    required this.onTabChange,
    required this.liveKey,
    required this.moviesKey,
    required this.seriesKey,
    required this.liveSearch,
    required this.moviesSearch,
    required this.seriesSearch,
    required this.onLiveSearch,
    required this.onMoviesSearch,
    required this.onSeriesSearch,
  });

  final int tabIndex;
  final ValueChanged<int> onTabChange;
  final String liveKey, moviesKey, seriesKey;
  final TextEditingController liveSearch, moviesSearch, seriesSearch;
  final ValueChanged<String> onLiveSearch, onMoviesSearch, onSeriesSearch;

  static const _navItems = [
    (icon: FontAwesomeIcons.tv, label: 'Live TV'),
    (icon: FontAwesomeIcons.film, label: 'Movies'),
    (icon: FontAwesomeIcons.clapperboard, label: 'Series'),
    (icon: FontAwesomeIcons.heart, label: 'Favorites'),
    (icon: FontAwesomeIcons.rotate, label: 'Catch Up'),
    (icon: FontAwesomeIcons.gear, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBackDark,
      body: Ink(
        decoration: kDecorBackground,
        child: Row(
          children: [
            // ── Sidebar ──────────────────────────────────────────────
            FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: kColorBackDark.withValues(alpha: .95),
                  border: Border(
                    right: BorderSide(
                      color: kColorHint.withValues(alpha: .3),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Logo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Image.asset(
                            kIconSplash,
                            width: 36,
                            height: 36,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            kAppName,
                            style: Get.textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Divider(
                      color: kColorHint.withValues(alpha: .3),
                      indent: 16,
                      endIndent: 16,
                    ),
                    const SizedBox(height: 8),

                    // Nav items
                    ...List.generate(_navItems.length, (i) {
                      final item = _navItems[i];
                      if (i >= 4) {
                        // Settings/CatchUp → navigate out
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: HomeNavItem(
                            title: item.label,
                            icon: item.icon,
                            isSelected: false,
                            autofocus: i == 0,
                            onTap: () {
                              if (i == 4) Get.toNamed(screenCatchUp);
                              if (i == 5) Get.toNamed(screenSettings);
                            },
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: HomeNavItem(
                          title: item.label,
                          icon: item.icon,
                          isSelected: tabIndex == i,
                          autofocus: i == 0,
                          onTap: () => onTabChange(i),
                        ),
                      );
                    }),

                    const Spacer(),

                    // User info at bottom
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is AuthSuccess) {
                          final user = state.user.userInfo;
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(
                                  color: kColorHint.withValues(alpha: .3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user?.username ?? '',
                                  style: Get.textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Expires: ${expirationDate(user?.expDate)}',
                                  style: Get.textTheme.bodySmall!.copyWith(
                                    color: kColorHint,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Content area ─────────────────────────────────────────
            Expanded(
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: IndexedStack(
                  index: tabIndex,
                  children: [
                    _LiveCategoriesTab(searchKey: liveKey, isTvLayout: true),
                    _MovieCategoriesTab(
                      searchKey: moviesKey,
                      isTvLayout: true,
                    ),
                    _SeriesCategoriesTab(
                      searchKey: seriesKey,
                      isTvLayout: true,
                    ),
                    const _FavoritesTab(isTvLayout: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BOTTOM NAVIGATION BAR ───────────────────────────────────────────────────

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

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
  const _LiveCategoriesTab({this.searchKey = '', this.isTvLayout = false});

  final String searchKey;
  final bool isTvLayout;

  int get _crossAxisCount => isTvLayout ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingState) {
        final isDemo = settingState.isDemo;
        return BlocBuilder<LiveCatyBloc, LiveCatyState>(
          builder: (context, state) {
            if (state is LiveCatyLoading) {
              return const _LoadingState();
            }

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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: isTvLayout ? 4.5 : 4,
              ),
              itemBuilder: (_, i) {
                final model = items[i];
                return CardLiveItem(
                  title: model.categoryName ?? '',
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
                      Get.to(
                        () => LiveChannelsScreen(
                          catyId: model.categoryId ?? '',
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── MOVIES CATEGORIES TAB ────────────────────────────────────────────────────

class _MovieCategoriesTab extends StatelessWidget {
  const _MovieCategoriesTab({
    this.searchKey = '',
    this.isTvLayout = false,
  });

  final String searchKey;
  final bool isTvLayout;

  int get _crossAxisCount => isTvLayout ? 4 : 2;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingState) {
        final isDemo = settingState.isDemo;
        return BlocBuilder<MovieCatyBloc, MovieCatyState>(
          builder: (context, state) {
            if (state is MovieCatyLoading) {
              return const _LoadingState();
            }

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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: isTvLayout ? 4.5 : 4,
              ),
              itemBuilder: (_, i) {
                final model = items[i];
                return CardLiveItem(
                  title: model.categoryName ?? '',
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
                        () => MovieChannels(catyId: model.categoryId ?? ''),
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── SERIES CATEGORIES TAB ───────────────────────────────────────────────────

class _SeriesCategoriesTab extends StatelessWidget {
  const _SeriesCategoriesTab({
    this.searchKey = '',
    this.isTvLayout = false,
  });

  final String searchKey;
  final bool isTvLayout;

  int get _crossAxisCount => isTvLayout ? 4 : 2;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingState) {
        final isDemo = settingState.isDemo;
        return BlocBuilder<SeriesCatyBloc, SeriesCatyState>(
          builder: (context, state) {
            if (state is SeriesCatyLoading) {
              return const _LoadingState();
            }

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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: isTvLayout ? 4.5 : 4,
              ),
              itemBuilder: (_, i) {
                final model = items[i];
                return CardLiveItem(
                  title: model.categoryName ?? '',
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
                          catyId: model.categoryId ?? '',
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── FAVORITES TAB ────────────────────────────────────────────────────────────

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab({this.isTvLayout = false});
  final bool isTvLayout;

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  int _subTab = 0; // 0=Live, 1=Movies, 2=Series

  int get _movieCols => widget.isTvLayout ? 6 : 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab selector
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

        // Content
        Expanded(
          child: IndexedStack(
            index: _subTab,
            children: [
              _FavLiveList(),
              _FavMoviesList(cols: _movieCols),
              _FavSeriesList(cols: _movieCols),
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
      child: InkWell(
        onTap: onTap,
        focusColor: kColorFocus.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(10),
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
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
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

// ─── SHARED UTILS ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: kColorPrimary),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FontAwesomeIcons.boxOpen,
              size: 40,
              color: kColorHint,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Get.textTheme.bodyMedium!.copyWith(color: kColorHint),
            ),
          ],
        ),
      );
}
