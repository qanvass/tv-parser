import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

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
import '../../repository/api/search_index_service.dart';
import '../../repository/api/local_market_service.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/spotlight_event.dart';
import '../../repository/models/premium_plus_item.dart';
import '../../repository/api/premium_plus_service.dart';
import 'widgets/tv_utility_cards_row.dart';
import 'widgets/tv_premium_plus_row.dart';
import 'widgets/tv_home_rows.dart';
import 'tv_search_screen.dart';

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

class _TvDashboardShellState extends State<TvDashboardShell> {
  int _selectedNavIndex = _TvNav.live;
  bool _loading = false;
  bool _railCollapsed = false;

  static const int _primaryCount = 6;

  final List<FocusNode> _navFocusNodes = List.generate(
    _primaryCount,
    (i) => FocusNode(debugLabel: 'TvNavPrimary$i'),
  );
  final List<FocusNode> _utilityFocusNodes = [
    FocusNode(debugLabel: 'TvNavSettings'),
  ];

  late final List<TvNavigationItem> _navItems;
  late final List<TvNavigationItem> _utilityItems;

  List<TvChannelRow> _liveRows = [];
  List<TvChannelRow> _movieRows = [];
  List<TvChannelRow> _seriesRows = [];
  List<SpotlightEvent> _tvSpotlightEvents = [];
  List<ChannelLive> _tvAllLiveChannels = [];
  List<PremiumPlusItem> _tvPremiumPlusItems = [];

  @override
  void initState() {
    super.initState();

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
    });
  }

  void _loadRealPlaylistContent() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final liveCatyState = context.read<LiveCatyBloc>().state;
    final movieCatyState = context.read<MovieCatyBloc>().state;
    final seriesCatyState = context.read<SeriesCatyBloc>().state;

    final liveCats = liveCatyState is LiveCatySuccess
        ? liveCatyState.categories
        : <CategoryModel>[];
    final movieCats = movieCatyState is MovieCatySuccess
        ? movieCatyState.categories
        : <CategoryModel>[];
    final seriesCats = seriesCatyState is SeriesCatySuccess
        ? seriesCatyState.categories
        : <CategoryModel>[];

    final profile = UserPreferenceProfile.load();
    final api = IpTvApi();
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    List<ChannelLive> allLives = [];
    List<ChannelMovie> allMovies = [];
    List<ChannelSerie> allSeries = [];
    List<SpotlightEvent> spots = [];

    try {
      final results = await Future.wait([
        api.getLiveChannels(""),
        api.getMovieChannels(""),
        api.getSeriesChannels(""),
      ]);
      allLives = results[0] as List<ChannelLive>;
      allMovies = results[1] as List<ChannelMovie>;
      allSeries = results[2] as List<ChannelSerie>;

      final adultCategoryIds = <String>{};
      for (final cat in [...liveCats, ...movieCats, ...seriesCats]) {
        if (cat.categoryName != null &&
            ProviderCurationRules.isAdultCategory(cat.categoryName!)) {
          if (cat.categoryId != null) {
            adultCategoryIds.add(cat.categoryId!);
          }
        }
      }

      SearchIndexService.buildIndex(
        liveChannels: allLives,
        movies: allMovies,
        series: allSeries,
        adultCategoryIds: adultCategoryIds,
      );

      spots = await EventDiscoveryService.getSpotlightEvents(
        region: profile.region,
      );
    } catch (_) {}

    final Map<String, String> categoryIdToName = {
      for (final cat in [...liveCats, ...movieCats, ...seriesCats])
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!,
    };

    final premiumPlusItems = PremiumPlusService.matchPremiumPlusChannels(
      allLives,
      categoryIdToName: categoryIdToName,
      forceRefresh: true,
    );

    if (mounted) {
      setState(() {
        _tvAllLiveChannels = allLives;
        _tvSpotlightEvents = spots;
        _tvPremiumPlusItems = premiumPlusItems;
      });
    }

    if (liveCatyState is LiveCatySuccess) {
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
      final topCats = sortedCats.take(5).toList();
      final List<TvChannelRow> rows = [];
      for (final cat in topCats) {
        if (cat.categoryId != null) {
          try {
            final chs = await api.getLiveChannels(cat.categoryId!);
            final sortedChs = ContentIntelligenceService.sortLives(
              chs,
              profile,
              categories,
            );
            final List<TvStreamRecord> records = [];
            for (final ch in sortedChs.take(15)) {
              String streamUrl = '';
              if (ch.directSource != null && ch.directSource!.isNotEmpty) {
                streamUrl = ch.directSource!;
              } else if (ch.streamId != null) {
                streamUrl = await PlaybackUrlBuilder.buildLiveUrl(ch.streamId!);
              }
              records.add(
                TvStreamRecord(
                  title: ch.name ?? 'Live Stream',
                  subtitle: cat.categoryName ?? 'Live',
                  streamUrl: streamUrl,
                  imageUrl: ch.streamIcon,
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
      }
      if (mounted && rows.isNotEmpty) {
        setState(() {
          _liveRows = [
            ...rows,
            const TvChannelRow(
              title: "Restricted Content",
              streams: [
                TvStreamRecord(
                  title: "Adult / 18+",
                  subtitle: "Enter PIN to unlock",
                  streamUrl: "adult_locked",
                ),
              ],
            ),
          ];
        });
      }
    }

    if (movieCatyState is MovieCatySuccess) {
      final categories = movieCats;
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
      final topCats = sortedCats.take(3).toList();
      final List<TvChannelRow> rows = [];
      for (final cat in topCats) {
        if (cat.categoryId != null) {
          try {
            final chs = await api.getMovieChannels(cat.categoryId!);
            final sortedChs = ContentIntelligenceService.sortMovies(
              chs,
              profile,
              categories,
            );
            final List<TvStreamRecord> records = [];
            for (final ch in sortedChs.take(15)) {
              String streamUrl = '';
              if (ch.directSource != null && ch.directSource!.isNotEmpty) {
                streamUrl = ch.directSource!;
              } else if (ch.streamId != null) {
                streamUrl = await PlaybackUrlBuilder.buildMovieUrl(
                  ch.streamId!,
                  containerExtension: ch.containerExtension,
                );
              }
              records.add(
                TvStreamRecord(
                  title: ch.name ?? 'Movie',
                  subtitle: "Rating: ${ch.rating ?? '5.0'}",
                  streamUrl: streamUrl,
                  imageUrl: ch.streamIcon,
                ),
              );
            }
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
      }
      if (mounted && rows.isNotEmpty) {
        setState(() {
          _movieRows = rows;
        });
      }
    }

    if (seriesCatyState is SeriesCatySuccess) {
      final categories = seriesCats;
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
      final topCats = sortedCats.take(3).toList();
      final List<TvChannelRow> rows = [];
      for (final cat in topCats) {
        if (cat.categoryId != null) {
          try {
            final chs = await api.getSeriesChannels(cat.categoryId!);
            final sortedChs = ContentIntelligenceService.sortSeries(
              chs,
              profile,
              categories,
            );
            final List<TvStreamRecord> records = [];
            for (final ch in sortedChs.take(15)) {
              String streamUrl = '';
              if (ch.seriesId != null) {
                streamUrl = await PlaybackUrlBuilder.buildSeriesUrl(
                  ch.seriesId!,
                );
              }
              records.add(
                TvStreamRecord(
                  title: ch.name ?? 'Series',
                  subtitle: "Rating: ${ch.rating ?? '5.0'}",
                  streamUrl: streamUrl,
                  imageUrl: ch.cover,
                ),
              );
            }
            if (records.isNotEmpty) {
              rows.add(
                TvChannelRow(
                  title: cat.categoryName ?? 'Series Shows',
                  streams: records,
                ),
              );
            }
          } catch (_) {}
        }
      }
      if (mounted && rows.isNotEmpty) {
        setState(() {
          _seriesRows = rows;
        });
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onPrimarySelected(int index) {
    if (index == _TvNav.favorites) {
      Get.toNamed(screenFavourite)?.then((_) {
        if (mounted) _navFocusNodes[_TvNav.favorites].requestFocus();
      });
      return;
    }
    if (index == _TvNav.history) {
      Get.toNamed(screenCatchUp)?.then((_) {
        if (mounted) _navFocusNodes[_TvNav.history].requestFocus();
      });
      return;
    }

    setState(() {
      _selectedNavIndex = index;
      _railCollapsed = index == _TvNav.search;
    });
  }

  void _onUtilitySelected(int index) {
    if (index == 0) {
      Get.toNamed(screenSettings)?.then((_) {
        if (mounted && _utilityFocusNodes.isNotEmpty) {
          _utilityFocusNodes.first.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    for (final node in _utilityFocusNodes) {
      node.dispose();
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
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scaffold(
          backgroundColor: const Color(0xFF050508),
          body: SafeArea(
            child: Padding(
              // Overscan-safe padding for Android TV
              padding: const EdgeInsets.symmetric(
                horizontal: 48.0,
                vertical: 36.0,
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
                  const SizedBox(width: 34),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          selectedLabel: _navItems[_selectedNavIndex].label,
                        ),
                        const SizedBox(height: 28),
                        Expanded(child: _buildContentPane()),
                      ],
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

  Widget _buildContentPane() {
    if (_selectedNavIndex == _TvNav.search) {
      return TvSearchScreen(
        embedded: true,
        onChannelSelected: widget.onChannelSelected,
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }

    return TvChannelGrid(
      rows: _visibleRowsForTab(_selectedNavIndex),
      onChannelSelected: widget.onChannelSelected,
      header: _selectedNavIndex == _TvNav.live ? _buildLiveTvHeader() : null,
    );
  }

  Widget? _buildLiveTvHeader() {
    final activeMarket = LocalMarketService.getActiveMarket();
    final profile = UserPreferenceProfile.load();
    final hasLocal = profile.locationFeatureEnabled && activeMarket != null;
    final hasSpotlight = _tvSpotlightEvents.isNotEmpty;
    final hasPremiumPlus = _tvPremiumPlusItems.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TvUserGreeting(),
        const SizedBox(height: 20),
        TvUtilityCardsRow(
          allLiveChannels: _tvAllLiveChannels,
          onChannelSelected: widget.onChannelSelected,
          showLocal: hasLocal,
        ),
        const SizedBox(height: 28),
        TvHomeRows(
          allLiveChannels: _tvAllLiveChannels,
          onChannelSelected: widget.onChannelSelected,
        ),
        if (hasSpotlight) ...[
          TvLiveSpotlightRow(
            events: _tvSpotlightEvents,
            allLiveChannels: _tvAllLiveChannels,
            onChannelSelected: widget.onChannelSelected,
          ),
          const SizedBox(height: 28),
        ],
        if (hasPremiumPlus) ...[
          TvPremiumPlusRow(
            items: _tvPremiumPlusItems,
            onPlayChannel: (ch) {
              if (ch is ChannelLive &&
                  ch.directSource != null &&
                  ch.directSource!.isNotEmpty) {
                widget.onChannelSelected(ch.directSource!);
              } else if (ch is ChannelLive && ch.streamId != null) {
                widget.onChannelSelected(ch.streamId!);
              }
            },
          ),
          const SizedBox(height: 28),
        ],
        if (hasLocal) ...[
          TvLocalTvRow(
            allLiveChannels: _tvAllLiveChannels,
            onChannelSelected: widget.onChannelSelected,
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  List<TvChannelRow> _visibleRowsForTab(int index) {
    switch (index) {
      case _TvNav.live:
        return _liveRows;
      case _TvNav.movies:
        return _movieRows;
      case _TvNav.series:
        return _seriesRows;
      default:
        return _liveRows;
    }
  }
}

class _Header extends StatelessWidget {
  final String selectedLabel;

  const _Header({required this.selectedLabel});

  @override
  Widget build(BuildContext context) {
    return Text(
      selectedLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 38,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.0,
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

        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              child: const Icon(Icons.person, color: Colors.white70, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $username",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      expDateStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
