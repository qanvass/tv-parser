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

class TvDashboardShell extends StatefulWidget {
  final ValueChanged<String> onChannelSelected;

  const TvDashboardShell({
    super.key,
    required this.onChannelSelected,
  });

  @override
  State<TvDashboardShell> createState() => _TvDashboardShellState();
}

class _TvDashboardShellState extends State<TvDashboardShell> {
  int _selectedNavIndex = 0;
  bool _loading = false;

  final List<FocusNode> _navFocusNodes = List.generate(
    4,
    (_) => FocusNode(debugLabel: 'TvNavigationItem'),
  );

  late final List<TvNavigationItem> _navItems;
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
      TvNavigationItem(
        label: 'Live TV',
        icon: Icons.live_tv_rounded,
      ),
      TvNavigationItem(
        label: 'Movies',
        icon: Icons.local_movies_rounded,
      ),
      TvNavigationItem(
        label: 'Series',
        icon: Icons.tv_rounded,
      ),
      TvNavigationItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
      ),
    ];

    _buildInitialMockContent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navFocusNodes.isNotEmpty) {
        _navFocusNodes.first.requestFocus();
      }
      _loadRealPlaylistContent();
    });
  }

  void _buildInitialMockContent() {
    _liveRows = List.generate(4, (rowIndex) {
      return TvChannelRow(
        title: rowIndex == 0 ? 'Featured Live TV' : 'Live Categories Loading...',
        streams: List.generate(8, (itemIndex) {
          return TvStreamRecord(
            title: 'Live Stream ${itemIndex + 1}',
            subtitle: 'Live • HD',
            streamUrl: 'mock://stream/$rowIndex/$itemIndex',
          );
        }),
      );
    });
    _movieRows = List.generate(3, (rowIndex) {
      return TvChannelRow(
        title: rowIndex == 0 ? 'Featured Movies' : 'Movie Categories Loading...',
        streams: List.generate(8, (itemIndex) {
          return TvStreamRecord(
            title: 'Movie Stream ${itemIndex + 1}',
            subtitle: 'VOD • HD',
            streamUrl: 'mock://stream/movie/$rowIndex/$itemIndex',
          );
        }),
      );
    });
    _seriesRows = List.generate(3, (rowIndex) {
      return TvChannelRow(
        title: rowIndex == 0 ? 'Featured Series' : 'Series Categories Loading...',
        streams: List.generate(8, (itemIndex) {
          return TvStreamRecord(
            title: 'Series Stream ${itemIndex + 1}',
            subtitle: 'Series • HD',
            streamUrl: 'mock://stream/series/$rowIndex/$itemIndex',
          );
        }),
      );
    });
  }

  void _loadRealPlaylistContent() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    // Read bloc states BEFORE async gaps to prevent warnings
    final liveCatyState = context.read<LiveCatyBloc>().state;
    final movieCatyState = context.read<MovieCatyBloc>().state;
    final seriesCatyState = context.read<SeriesCatyBloc>().state;

    final liveCats = liveCatyState is LiveCatySuccess ? liveCatyState.categories : <CategoryModel>[];
    final movieCats = movieCatyState is MovieCatySuccess ? movieCatyState.categories : <CategoryModel>[];
    final seriesCats = seriesCatyState is SeriesCatySuccess ? seriesCatyState.categories : <CategoryModel>[];

    final profile = UserPreferenceProfile.load();
    final api = IpTvApi();
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Load all live channels across all categories first for matching and indexing
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

      // Compile adult category IDs to exclude them from the global search index
      final adultCategoryIds = <String>{};
      for (final cat in [...liveCats, ...movieCats, ...seriesCats]) {
        if (cat.categoryName != null && ProviderCurationRules.isAdultCategory(cat.categoryName!)) {
          if (cat.categoryId != null) {
            adultCategoryIds.add(cat.categoryId!);
          }
        }
      }

      // Build search index asynchronously (does not block UI thread)
      SearchIndexService.buildIndex(
        liveChannels: allLives,
        movies: allMovies,
        series: allSeries,
        adultCategoryIds: adultCategoryIds,
      );

      spots = await EventDiscoveryService.getSpotlightEvents(region: profile.region);
    } catch (_) {}

    final Map<String, String> categoryIdToName = {
      for (final cat in [...liveCats, ...movieCats, ...seriesCats])
        if (cat.categoryId != null && cat.categoryName != null)
          cat.categoryId!: cat.categoryName!
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

    // 1. Load Live TV Rows
    if (liveCatyState is LiveCatySuccess) {
      final categories = liveCats;
      final normalCats = categories
          .where((c) => c.categoryName != null && !ProviderCurationRules.isAdultCategory(c.categoryName!))
          .toList();
      final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(normalCats);
      final topCats = sortedCats.take(5).toList();
      final List<TvChannelRow> rows = [];
      for (final cat in topCats) {
        if (cat.categoryId != null) {
          try {
            final chs = await api.getLiveChannels(cat.categoryId!);
            final sortedChs = ContentIntelligenceService.sortLives(chs, profile, categories);
            final List<TvStreamRecord> records = [];
            for (final ch in sortedChs.take(15)) {
              String streamUrl = '';
              if (ch.directSource != null && ch.directSource!.isNotEmpty) {
                streamUrl = ch.directSource!;
              } else if (ch.streamId != null) {
                streamUrl = await PlaybackUrlBuilder.buildLiveUrl(ch.streamId!);
              }
              records.add(TvStreamRecord(
                title: ch.name ?? 'Live Stream',
                subtitle: cat.categoryName ?? 'Live',
                streamUrl: streamUrl,
                imageUrl: ch.streamIcon,
              ));
            }
            if (records.isNotEmpty) {
              rows.add(TvChannelRow(title: cat.categoryName ?? 'Live TV', streams: records));
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

    // 2. Load Movie Rows
    if (movieCatyState is MovieCatySuccess) {
      final categories = movieCats;
      final normalCats = categories
          .where((c) => c.categoryName != null && !ProviderCurationRules.isAdultCategory(c.categoryName!))
          .toList();
      final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(normalCats);
      final topCats = sortedCats.take(3).toList();
      final List<TvChannelRow> rows = [];
      for (final cat in topCats) {
        if (cat.categoryId != null) {
          try {
            final chs = await api.getMovieChannels(cat.categoryId!);
            final sortedChs = ContentIntelligenceService.sortMovies(chs, profile, categories);
            final List<TvStreamRecord> records = [];
            for (final ch in sortedChs.take(15)) {
              String streamUrl = '';
              if (ch.directSource != null && ch.directSource!.isNotEmpty) {
                streamUrl = ch.directSource!;
              } else if (ch.streamId != null) {
                streamUrl = await PlaybackUrlBuilder.buildMovieUrl(ch.streamId!, containerExtension: ch.containerExtension);
              }
              records.add(TvStreamRecord(
                title: ch.name ?? 'Movie',
                subtitle: "Rating: ${ch.rating ?? '5.0'}",
                streamUrl: streamUrl,
                imageUrl: ch.streamIcon,
              ));
            }
            if (records.isNotEmpty) {
              rows.add(TvChannelRow(title: cat.categoryName ?? 'Movies', streams: records));
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

    // 3. Load Series Rows
    if (seriesCatyState is SeriesCatySuccess) {
      final categories = seriesCats;
      final normalCats = categories
          .where((c) => c.categoryName != null && !ProviderCurationRules.isAdultCategory(c.categoryName!))
          .toList();
      final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(normalCats);
      final topCats = sortedCats.take(3).toList();
      final List<TvChannelRow> rows = [];
      for (final cat in topCats) {
        if (cat.categoryId != null) {
          try {
            final chs = await api.getSeriesChannels(cat.categoryId!);
            final sortedChs = ContentIntelligenceService.sortSeries(chs, profile, categories);
            final List<TvStreamRecord> records = [];
            for (final ch in sortedChs.take(15)) {
              String streamUrl = '';
              if (ch.seriesId != null) {
                streamUrl = await PlaybackUrlBuilder.buildSeriesUrl(ch.seriesId!);
              }
              records.add(TvStreamRecord(
                title: ch.name ?? 'Series',
                subtitle: "Rating: ${ch.rating ?? '5.0'}",
                streamUrl: streamUrl,
                imageUrl: ch.cover,
              ));
            }
            if (records.isNotEmpty) {
              rows.add(TvChannelRow(title: cat.categoryName ?? 'Series Shows', streams: records));
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

  @override
  void dispose() {
    for (final node in _navFocusNodes) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: 48.0,
                vertical: 32.0,
              ),
              child: Row(
                children: [
                  TvNavigationRail(
                    items: _navItems,
                    selectedIndex: _selectedNavIndex,
                    focusNodes: _navFocusNodes,
                    onSelected: (index) {
                      setState(() {
                        _selectedNavIndex = index;
                      });
                    },
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
                        Expanded(
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(color: Colors.white24),
                                )
                              : TvChannelGrid(
                                  rows: _visibleRowsForTab(_selectedNavIndex),
                                  onChannelSelected: widget.onChannelSelected,
                                  header: _selectedNavIndex == 0
                                      ? _buildLiveTvHeader()
                                      : null,
                                ),
                        ),
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
        // 1. Greeting / user status area
        const TvUserGreeting(),
        const SizedBox(height: 20),

        // 2. Colorful utility cards row
        TvUtilityCardsRow(
          allLiveChannels: _tvAllLiveChannels,
          onChannelSelected: widget.onChannelSelected,
          showLocal: hasLocal,
        ),
        const SizedBox(height: 28),

        // 3. Live Tonight row
        if (hasSpotlight) ...[
          TvLiveSpotlightRow(
            events: _tvSpotlightEvents,
            allLiveChannels: _tvAllLiveChannels,
            onChannelSelected: widget.onChannelSelected,
          ),
          const SizedBox(height: 28),
        ],

        // 4. Premium Plus row
        if (hasPremiumPlus) ...[
          TvPremiumPlusRow(
            items: _tvPremiumPlusItems,
            onPlayChannel: (ch) {
              if (ch is ChannelLive && ch.directSource != null && ch.directSource!.isNotEmpty) {
                widget.onChannelSelected(ch.directSource!);
              } else if (ch is ChannelLive && ch.streamId != null) {
                widget.onChannelSelected(ch.streamId!);
              }
            },
          ),
          const SizedBox(height: 28),
        ],

        // 5. Local TV row
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
      case 0:
        return _liveRows;
      case 1:
        return _movieRows;
      case 2:
        return _seriesRows;
      case 3:
        // Settings triggers route navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.toNamed(screenSettings);
        });
        return const [];
      default:
        return _liveRows;
    }
  }
}

class _Header extends StatelessWidget {
  final String selectedLabel;

  const _Header({
    required this.selectedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            selectedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
        ),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'D-Pad Ready',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
            ? (state.user.userInfo?.username ?? 'Premium Member')
            : 'Premium Member';
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
