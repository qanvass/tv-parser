import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

import '../../helpers/helpers.dart';
import '../../logic/blocs/auth/auth_bloc.dart';
import '../../logic/blocs/categories/live_caty/live_caty_bloc.dart';
import '../../logic/blocs/categories/movie_caty/movie_caty_bloc.dart';
import '../../logic/blocs/categories/series_caty/series_caty_bloc.dart';
import '../../logic/cubits/watch/watching_cubit.dart';
import '../../logic/cubits/favorites/favorites_cubit.dart';
import '../../repository/api/api.dart';
import '../../repository/api/content_intelligence_service.dart';
import '../../repository/api/row_curation_service.dart';
import '../../repository/api/user_behavior_service.dart';
import '../../repository/models/category.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/user_preference_profile.dart';
import '../../repository/models/ranked_item.dart';
import '../screens/screens.dart';

import 'widgets/floating_bottom_nav.dart';
import 'widgets/hero_carousel.dart';
import '../../repository/api/hero_content_service.dart';
import '../../repository/api/youtube_trailer_search_service.dart';
import '../../repository/cache/trailer_cache_service.dart';
import 'widgets/horizontal_poster_rows.dart';
import 'widgets/live_category_chips.dart';
import 'widgets/live_spotlight_row.dart';
import '../../repository/api/location_preference_service.dart';
import '../../repository/api/event_discovery_service.dart';
import '../../repository/api/search_index_service.dart';
import '../../repository/api/local_market_service.dart';
import '../../repository/models/spotlight_event.dart';
import '../../repository/models/premium_plus_item.dart';
import 'widgets/premium_plus_row.dart';
import 'mobile_detail_screen.dart';
import 'mobile_search_screen.dart';
import 'all_content_screen.dart';
import 'local_tv_screen.dart';
import '../shared/widgets/stream_launcher.dart';

class MobileWatchScreen extends StatefulWidget {
  const MobileWatchScreen({super.key});

  @override
  State<MobileWatchScreen> createState() => _MobileWatchScreenState();
}

class _MobileWatchScreenState extends State<MobileWatchScreen> {
  int _currentNavIndex = 0;

  // Curated Lists loaded via RowCurationService
  List<ChannelMovie> _featuredMovies = [];
  List<ChannelSerie> _featuredSeries = [];
  List<ChannelMovie> _heroCarouselItems = [];
  List<HeroCarouselItem> _enrichedHeroItems = [];
  List<ChannelLive> _sportsChannels = [];
  List<ChannelLive> _recommendedLiveChannels = []; // Reused for Local/News
  List<RankedItem<dynamic>> _conciergePicks = [];
  List<SpotlightEvent> _spotlightEvents = [];
  List<ChannelLive> _allLiveChannelsForMatching = [];
  List<PremiumPlusItem> _premiumPlusItems = [];

  CategoryModel? _selectedLiveCategory;
  List<ChannelLive> _currentCategoryLiveChannels = [];
  bool _loadingLiveChannels = false;
  bool _loadingVod = false;

  @override
  void initState() {
    super.initState();
    _loadAllCuration();
    _checkOnboarding();
  }

  /// Onboarding check
  void _checkOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = UserPreferenceProfile.load();
      if (profile.country == null) {
        _showOnboardingSheet();
      } else if (LocationPreferenceService.shouldShowExplainer()) {
        _showLocationExplainerSheet();
      } else {
        _syncLocationSilently();
      }
    });
  }

  /// Silently checks and syncs location personalization
  Future<void> _syncLocationSilently() async {
    final profile = UserPreferenceProfile.load();
    if (profile.locationFeatureEnabled) {
      final status = await LocationPreferenceService.checkPermissionStatusSilently();
      if (status == 'granted') {
        await LocationPreferenceService.requestLocationPersonalization();
        _loadAllCuration();
      }
    }
  }

  /// Location permission explainer sheet (compliant memory system)
  void _showLocationExplainerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.location_on_rounded, size: 56, color: Colors.amber),
              const SizedBox(height: 18),
              const Text(
                "Show Local Channels?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                "TV Parser uses your approximate location to help surface local channels and region-relevant live events from your available playlist.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () async {
                  Get.back();
                  await LocationPreferenceService.requestLocationPersonalization();
                  _loadAllCuration();
                },
                child: const Text("Allow Local Suggestions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () async {
                  Get.back();
                  await LocationPreferenceService.markExplainerSeen(false);
                },
                child: const Text("Not Now", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Initial onboarding dialogue prompt
  void _showOnboardingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.travel_explore_rounded, size: 56, color: Colors.amber),
              const SizedBox(height: 18),
              const Text(
                "Help TV Parser organize channels?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                "We will personalize your homepage by prioritizing news, sports, and live categories relevant to your language and location. No precise GPS is tracked.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 28),

              // Button: Use Approx Location (US Default)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () async {
                  final profile = UserPreferenceProfile.load();
                  final updated = profile.copyWith(
                    country: "USA", 
                    language: "English",
                    prefersSports: true,
                    prefersNews: true,
                  );
                  await updated.save();
                  Get.back();
                  _loadAllCuration();
                  _showSuccessToast("Organized for USA & English!");
                },
                icon: const Icon(Icons.my_location_rounded, color: Colors.black, size: 18),
                label: const Text("Use Approximate Location", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              const SizedBox(height: 12),

              // Button: Choose Country & Language
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () {
                  Get.back();
                  _showManualSelectionSheet();
                },
                icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                label: const Text("Choose Country & Language", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(height: 12),

              // Button: Skip
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("Skip", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Expanded Manual Preference Panel (Onboarding selections)
  void _showManualSelectionSheet() {
    String selectedCountry = "USA";
    String selectedState = "Georgia";
    String selectedLang = "English";
    bool prefersSports = true;
    bool prefersNews = true;
    bool prefersKids = false;
    bool hideAdult = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Intelligent Personalization Setup",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),

                  // Country Selection
                  const Text("Country / Region", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFF222225), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButton<String>(
                      value: selectedCountry,
                      dropdownColor: const Color(0xFF161618),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      underline: const SizedBox(),
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCountry = val);
                      },
                      items: ["USA", "United Kingdom", "Canada", "Spain", "Mexico", "France", "Germany", "Others"]
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Region / State Selection
                  const Text("State / Territory", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF222225),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (val) => selectedState = val,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter state/city (e.g. Georgia, Atlanta, London)",
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Language Selection
                  const Text("Language Preference", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFF222225), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButton<String>(
                      value: selectedLang,
                      dropdownColor: const Color(0xFF161618),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      underline: const SizedBox(),
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedLang = val);
                      },
                      items: ["English", "Spanish", "French", "Arabic", "Portuguese", "Hindi", "Others"]
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Preferences Switches
                  const Text("Prioritized Categories", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    title: const Text("Show Sports First", style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: prefersSports,
                    activeColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => setModalState(() => prefersSports = val),
                  ),
                  SwitchListTile(
                    title: const Text("Show Local & Breaking News", style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: prefersNews,
                    activeColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => setModalState(() => prefersNews = val),
                  ),
                  SwitchListTile(
                    title: const Text("Family & Kids Priority", style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: prefersKids,
                    activeColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => setModalState(() => prefersKids = val),
                  ),
                  SwitchListTile(
                    title: const Text("Hide Adult Channels", style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: hideAdult,
                    activeColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => setModalState(() => hideAdult = val),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () async {
                      final profile = UserPreferenceProfile.load();
                      final updated = profile.copyWith(
                        country: selectedCountry,
                        region: selectedState,
                        language: selectedLang,
                        prefersSports: prefersSports,
                        prefersNews: prefersNews,
                        prefersKids: prefersKids,
                        hideAdultContent: hideAdult,
                      );
                      await updated.save();
                      Get.back();
                      _loadAllCuration();
                      _showSuccessToast("Curation engine updated!");
                    },
                    child: const Text("Apply Preferences", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Unified Curation loader prefetching all playlist records into memory 
  /// and building rows utilizing strict Curation Row Rules
  Future<void> _loadAllCuration() async {
    if (mounted) setState(() => _loadingVod = true);

    try {
      final api = IpTvApi();
      final results = await Future.wait([
        api.getLiveChannels(""),
        api.getMovieChannels(""),
        api.getSeriesChannels(""),
      ]);

      final allLives = results[0] as List<ChannelLive>;
      final allMovies = results[1] as List<ChannelMovie>;
      final allSeries = results[2] as List<ChannelSerie>;

      final profile = UserPreferenceProfile.load();

      // Compile adult category IDs to exclude them from the global search index
      final liveCatyState = context.read<LiveCatyBloc>().state;
      final movieCatyState = context.read<MovieCatyBloc>().state;
      final seriesCatyState = context.read<SeriesCatyBloc>().state;

      final liveCats = liveCatyState is LiveCatySuccess ? liveCatyState.categories : <CategoryModel>[];
      final movieCats = movieCatyState is MovieCatySuccess ? movieCatyState.categories : <CategoryModel>[];
      final seriesCats = seriesCatyState is SeriesCatySuccess ? seriesCatyState.categories : <CategoryModel>[];

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

      // Load active Live Spotlight events
      final spots = await EventDiscoveryService.getSpotlightEvents(region: profile.region);

      final categories = liveCatyState is LiveCatySuccess ? liveCatyState.categories : <CategoryModel>[];

      // Curate unique horizontal content rows strictly in background isolate
      final curationParams = CurationParams(
        lives: allLives,
        movies: allMovies,
        series: allSeries,
        profile: profile,
        categories: categories,
      );
      final curationResult = await compute(performBackgroundCuration, curationParams);

      if (mounted) {
        setState(() {
          _heroCarouselItems = curationResult.heroRanked.map((r) => r.item).toList();
          _featuredMovies = curationResult.trendingMovies;
          _featuredSeries = curationResult.featuredSeries;
          _sportsChannels = curationResult.sports;
          _recommendedLiveChannels = curationResult.news;
          _conciergePicks = curationResult.concierge;
          _spotlightEvents = spots;
          _allLiveChannelsForMatching = allLives;
          _premiumPlusItems = curationResult.premiumPlusItems;
          _loadingVod = false;
        });

        _enrichHeroCarousel();
      }
    } catch (e) {
      debugPrint("Intelligent Curation Engine error: $e");
      if (mounted) setState(() => _loadingVod = false);
    }
  }

  Future<void> _enrichHeroCarousel() async {
    if (!mounted) return;

    try {
      final enriched = await HeroContentService.fetchAndEnrichHeroItems(_heroCarouselItems);
      if (mounted) {
        setState(() {
          _enrichedHeroItems = enriched;
        });

        // Trigger background search queue for missing VOD trailers
        _startBackgroundTrailerEnrichment(enriched);
      }
    } catch (e) {
      debugPrint("[MOBILE_WATCH_SCREEN] Error enriching hero items: $e");
    }
  }

  Future<void> _startBackgroundTrailerEnrichment(List<HeroCarouselItem> items) async {
    // Filter out items that are VOD, have a valid image, and don't have a trailer
    final List<HeroCarouselItem> targetItems = items.where((item) {
      if (!item.isVod) return false;
      if (item.trailerYoutubeId != null && item.trailerYoutubeId!.isNotEmpty) return false;
      return true;
    }).toList();

    if (targetItems.isEmpty) return;

    int index = 0;

    Future<void> processNext() async {
      if (!mounted || index >= targetItems.length) return;
      
      final currentItem = targetItems[index++];

      try {
        final cleanTitle = currentItem.cleanTitle ?? currentItem.title;
        final year = currentItem.year;

        // Perform search lookup
        final trailerId = await YouTubeTrailerSearchService.findTrailerYoutubeId(
          cleanTitle: cleanTitle,
          year: year,
        );

        if (trailerId != null && trailerId.isNotEmpty) {
          // Success! Write to cache
          TrailerCacheService.writeEntry(
            title: cleanTitle,
            year: year,
            youtubeId: trailerId,
            source: 'youtubeApi',
            failedLookup: false,
          );

          if (mounted) {
            setState(() {
              // Update the item in _enrichedHeroItems
              final idx = _enrichedHeroItems.indexWhere((x) => x.id == currentItem.id);
              if (idx != -1) {
                final original = _enrichedHeroItems[idx];
                _enrichedHeroItems[idx] = HeroCarouselItem(
                  id: original.id,
                  title: original.title,
                  cleanTitle: original.cleanTitle,
                  year: original.year,
                  description: original.description,
                  imageUrl: original.imageUrl,
                  trailerYoutubeId: trailerId,
                  previewType: HeroPreviewType.trailer,
                  isLive: original.isLive,
                  isVod: original.isVod,
                  rawMovie: original.rawMovie,
                );
              }
            });
          }
        } else {
          // Failed! Write failed lookup cache entry (7 days TTL)
          TrailerCacheService.writeEntry(
            title: cleanTitle,
            year: year,
            youtubeId: null,
            source: 'none',
            failedLookup: true,
          );
        }
      } catch (e) {
        debugPrint("[MOBILE_WATCH_SCREEN] Background trailer search error for '${currentItem.title}': $e");
      } finally {
        // Trigger next item in queue
        processNext();
      }
    }

    // Start initial concurrent request streams (max 2 concurrency)
    const maxConcurrency = 2;
    for (int i = 0; i < maxConcurrency; i++) {
      processNext();
    }
  }

  /// Category filter chips fetcher
  void _fetchLiveChannels(String categoryId) async {
    if (categoryId == 'virtual_for_you') {
      _loadAllCuration();
      return;
    }
    if (categoryId == 'virtual_all') {
      Get.to(() => const AllContentScreen(initialMode: BrowseMode.live));
      return;
    }

    if (mounted) {
      setState(() {
        _loadingLiveChannels = true;
      });
    }

    try {
      final api = IpTvApi();
      final chs = await api.getLiveChannels(categoryId);
      final profile = UserPreferenceProfile.load();
      final liveCatyState = context.read<LiveCatyBloc>().state;
      final categories = liveCatyState is LiveCatySuccess ? liveCatyState.categories : <CategoryModel>[];
      
      final sorted = ContentIntelligenceService.sortLives(chs, profile, categories);
      final deduped = ContentIntelligenceService.deduplicate<ChannelLive>(sorted, (c) => c.name ?? c.streamId ?? '');

      if (mounted) {
        setState(() {
          _currentCategoryLiveChannels = deduped;
          _loadingLiveChannels = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLiveChannels = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: Stack(
        children: [
          // Scrollable Core Dashboard (Displays on Index 0)
          _currentNavIndex == 0 ? _buildHomeWatchScreen() : _buildNavSubscreen(),

          // Glassmorphic Floating Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingBottomNav(
              selectedIndex: _currentNavIndex,
              onTap: (index) {
                setState(() {
                  _currentNavIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeWatchScreen() {
    final watchState = context.watch<WatchingCubit>().state;
    final recentLives = watchState.live;
    final favState = context.watch<FavoritesCubit>().state;

    final liveCatyState = context.watch<LiveCatyBloc>().state;
    final liveCategories = liveCatyState is LiveCatySuccess ? liveCatyState.categories : <CategoryModel>[];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100), // Widescreen scroll padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingVod || _loadingLiveChannels)
            const LinearProgressIndicator(color: Color(0xFFFFC107), backgroundColor: Colors.transparent, minHeight: 2.0),

          // LOCKED MOBILE WATCH SCREEN TOP TEMPLATE
          // Do not reorder, remove, rename, merge, recolor, replace, or move these top rows
          // without explicit user approval.
          // Approved locked order:
          // 1. HeroCarousel - main cinematic hero/banner carousel MUST stay at absolute top.
          //    Current hero examples: Fox 5 Live, The Devil Wears Prada 2,
//    Star Wars / Mandalorian, Pressure 2015, Masters of the Universe,
//    Scary Movie 2000, The Breadwinner.
          // 2. _buildUserGreetingSection()
          // 3. _buildBrowseEntryPoints()
          // 4. LiveCategoryChips and _currentCategoryLiveChannels, if active
          // 5. LiveSpotlightRow
          // 6. PremiumPlusRow
          // Future additions must go below this locked section by default.

          // 1. HeroCarousel - main cinematic hero/banner carousel at absolute top
          HeroCarousel(
            movies: _enrichedHeroItems,
            onPlayTap: (movie) => _onHeroPlayTap(movie),
            onInfoTap: (movie) => _onHeroInfoTap(movie),
          ),
          const SizedBox(height: 18),

          // 2. Greeting / Welcome Message using _buildUserGreetingSection()
          _buildUserGreetingSection(),
          const SizedBox(height: 16),

          // 3. Colorful Utility Cards Carousel using _buildBrowseEntryPoints()
          _buildBrowseEntryPoints(),
          const SizedBox(height: 20),

          // 4. Live TV Categories Row using LiveCategoryChips and _currentCategoryLiveChannels if active
          if (liveCategories.isNotEmpty) ...[
            LiveCategoryChips(
              categories: liveCategories,
              selectedCategoryId: _selectedLiveCategory?.categoryId ?? '',
              onCategorySelected: (cat) {
                setState(() {
                  _selectedLiveCategory = cat;
                });
                _fetchLiveChannels(cat.categoryId ?? '');
              },
            ),
            const SizedBox(height: 20),
          ],

          // Live Category Channels scrolling rows
          if (_currentCategoryLiveChannels.isNotEmpty) ...[
            HorizontalPosterRows(
              title: _selectedLiveCategory?.categoryName ?? 'Live TV',
              titleIcon: Icons.live_tv_rounded,
              titleIconColor: Theme.of(context).primaryColor,
              itemCount: _currentCategoryLiveChannels.length > 15 ? 15 : _currentCategoryLiveChannels.length,
              aspect: PosterAspect.landscape,
              itemBuilder: (context, index) {
                final channel = _currentCategoryLiveChannels[index];
                final isFav = favState.lives.any((l) => l.streamId == channel.streamId);
                return PosterCard(
                  title: channel.name ?? 'Live Channel',
                  imageUrl: channel.streamIcon,
                  aspect: PosterAspect.landscape,
                  isLive: true,
                  isFavorite: isFav,
                  onLongPress: () {
                    context.read<FavoritesCubit>().addLive(channel, isAdd: !isFav);
                    _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
                  },
                  onTap: () {
                    UserBehaviorService.trackClick(channel.streamId ?? '', channel.categoryId);
                    _onLiveChannelTap(channel);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // 5. Live Tonight Carousel using LiveSpotlightRow
          if (_spotlightEvents.isNotEmpty) ...[
            LiveSpotlightRow(
              events: _spotlightEvents,
              allLiveChannels: _allLiveChannelsForMatching,
              onPlayChannel: (channel) => _onLiveChannelTap(channel),
            ),
            const SizedBox(height: 20),
          ],

          // 6. Premium Plus Carousel using PremiumPlusRow
          PremiumPlusRow(
            items: _premiumPlusItems,
            onPlayChannel: (channel) => _onLiveChannelTap(channel),
          ),

          // Local TV Channels Row (Local TV Near You)
          _buildLocalTvChannelsRow(),

          // 4. Continue Watching (Landscape horizontal aspect rows)
          if (recentLives.isNotEmpty)
            HorizontalPosterRows(
              title: "Continue Watching",
              titleIcon: Icons.history_rounded,
              titleIconColor: const Color(0xFF00C6FF),
              itemCount: recentLives.length,
              aspect: PosterAspect.landscape,
              itemBuilder: (context, index) {
                final watchItem = recentLives[index];
                return PosterCard(
                  title: watchItem.title,
                  imageUrl: watchItem.image,
                  aspect: PosterAspect.landscape,
                  ratingBadge: watchItem.sliderValue > 0 ? "${(watchItem.sliderValue / (watchItem.durationStrm > 0 ? watchItem.durationStrm : 100) * 100).toInt()}% Done" : null,
                  onTap: () {
                    // Track click behavior
                    UserBehaviorService.trackClick(watchItem.streamId, null);
                    Get.to(() => MoviePlayerScreen(link: watchItem.stream, title: watchItem.title));
                  },
                );
              },
            ),

          // 5. For You Picks (Concierge Picks with dynamic learned scoring metrics)
          if (_conciergePicks.isNotEmpty)
            HorizontalPosterRows(
              title: "For You (Concierge Picks)",
              titleIcon: Icons.stars_rounded,
              titleIconColor: Colors.amber,
              itemCount: _conciergePicks.length,
              aspect: PosterAspect.landscape,
              itemBuilder: (context, index) {
                final rItem = _conciergePicks[index];
                final item = rItem.item;
                final bool isLive = rItem.contentType == 'live';
                final bool isMovie = rItem.contentType == 'movie';
                final String title = RankedItem.getItemTitle(item);
                final String? imageUrl = isLive ? item.streamIcon : item.streamIcon;

                final bool isFav = isLive
                    ? favState.lives.any((l) => l.streamId == item.streamId)
                    : isMovie
                        ? favState.movies.any((m) => m.streamId == item.streamId)
                        : favState.series.any((s) => s.seriesId == item.seriesId);

                return PosterCard(
                  title: title,
                  imageUrl: imageUrl,
                  aspect: PosterAspect.landscape,
                  isLive: isLive,
                  isFavorite: isFav,
                  ratingBadge: "Score: ${rItem.score.toInt()}",
                  onLongPress: () {
                    if (isLive) {
                      context.read<FavoritesCubit>().addLive(item, isAdd: !isFav);
                    } else if (isMovie) {
                      context.read<FavoritesCubit>().addMovie(item, isAdd: !isFav);
                    } else {
                      context.read<FavoritesCubit>().addSerie(item, isAdd: !isFav);
                    }
                    _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
                  },
                  onTap: () {
                    UserBehaviorService.trackClick(item.streamId ?? '', item.categoryId);
                    if (isLive) {
                      _onLiveChannelTap(item);
                    } else if (isMovie) {
                      _showMovieDetailSheet(item);
                    }
                  },
                );
              },
            ),



          // 8. Dedicating Live USA Sports Row (High-fidelity filters)
          if (_sportsChannels.isNotEmpty)
            HorizontalPosterRows(
              title: "USA & Global Sports",
              titleIcon: Icons.sports_kabaddi_rounded,
              titleIconColor: Colors.orange,
              itemCount: _sportsChannels.length,
              aspect: PosterAspect.landscape,
              itemBuilder: (context, index) {
                final sportCh = _sportsChannels[index];
                final isFav = favState.lives.any((l) => l.streamId == sportCh.streamId);
                return PosterCard(
                  title: sportCh.name ?? 'Sports Stream',
                  imageUrl: sportCh.streamIcon,
                  aspect: PosterAspect.landscape,
                  isLive: true,
                  isFavorite: isFav,
                  onLongPress: () {
                    context.read<FavoritesCubit>().addLive(sportCh, isAdd: !isFav);
                    _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
                  },
                  onTap: () {
                    UserBehaviorService.trackClick(sportCh.streamId ?? '', sportCh.categoryId);
                    _onLiveChannelTap(sportCh);
                  },
                );
              },
            ),

          // 9. Widescreen Movies rows (Strictly curated VOD Movies)
          HorizontalPosterRows(
            title: "Trending Movies",
            titleIcon: Icons.movie_rounded,
            titleIconColor: const Color(0xFFFF416C),
            itemCount: _featuredMovies.length,
            aspect: PosterAspect.vertical,
            itemBuilder: (context, index) {
              final movie = _featuredMovies[index];
              final isFav = favState.movies.any((m) => m.streamId == movie.streamId);
              return PosterCard(
                title: movie.name ?? 'Movie',
                imageUrl: movie.streamIcon,
                aspect: PosterAspect.vertical,
                isFavorite: isFav,
                ratingBadge: movie.rating != null ? "⭐ ${movie.rating}" : null,
                onLongPress: () {
                  context.read<FavoritesCubit>().addMovie(movie, isAdd: !isFav);
                  _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
                },
                onTap: () {
                  UserBehaviorService.trackClick(movie.streamId ?? '', movie.categoryId);
                  _showMovieDetailSheet(movie);
                },
              );
            },
            onSeeAllTap: () => Get.to(() => const AllContentScreen(initialMode: BrowseMode.movies)),
          ),

          // 10. Widescreen Series rows (Strictly curated Series)
          HorizontalPosterRows(
            title: "Featured Series",
            titleIcon: Icons.tv_rounded,
            titleIconColor: const Color(0xFF00C6FF),
            itemCount: _featuredSeries.length,
            aspect: PosterAspect.vertical,
            itemBuilder: (context, index) {
              final serie = _featuredSeries[index];
              final isFav = favState.series.any((s) => s.seriesId == serie.seriesId);
              return PosterCard(
                title: serie.name ?? 'Series',
                imageUrl: serie.cover,
                aspect: PosterAspect.vertical,
                isFavorite: isFav,
                ratingBadge: serie.rating != null ? "⭐ ${serie.rating}" : null,
                onLongPress: () {
                  context.read<FavoritesCubit>().addSerie(serie, isAdd: !isFav);
                  _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
                },
                onTap: () {
                  UserBehaviorService.trackClick(serie.seriesId ?? '', serie.categoryId);
                  Get.to(() => SerieContent(channelSerie: serie, videoId: serie.seriesId ?? ''));
                },
              );
            },
            onSeeAllTap: () => Get.to(() => const AllContentScreen(initialMode: BrowseMode.series)),
          ),

          // 11. Local News & Broadcasts Curation Row
          if (_recommendedLiveChannels.isNotEmpty)
            HorizontalPosterRows(
              title: "Local & National News",
              titleIcon: Icons.newspaper_rounded,
              titleIconColor: Colors.tealAccent,
              itemCount: _recommendedLiveChannels.length,
              aspect: PosterAspect.landscape,
              itemBuilder: (context, index) {
                final channel = _recommendedLiveChannels[index];
                final isFav = favState.lives.any((l) => l.streamId == channel.streamId);
                return PosterCard(
                  title: channel.name ?? 'News Feed',
                  imageUrl: channel.streamIcon,
                  aspect: PosterAspect.landscape,
                  isLive: true,
                  isFavorite: isFav,
                  onLongPress: () {
                    context.read<FavoritesCubit>().addLive(channel, isAdd: !isFav);
                    _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
                  },
                  onTap: () {
                    UserBehaviorService.trackClick(channel.streamId ?? '', channel.categoryId);
                    _onLiveChannelTap(channel);
                  },
                );
              },
            ),
          _buildAdultLockedCard(),
        ],
      ),
    );
  }

  Widget _buildAdultLockedCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: GestureDetector(
        onTap: _showAdultPinDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2D0A0A).withOpacity(0.15),
                const Color(0xFF1E1A30).withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2D0A0A).withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, color: Colors.red.shade700, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Adult / 18+",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Enter PIN to unlock",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdultPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        title: const Text("Adult Content Locked", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter PIN to unlock 18+ channels.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter PIN",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1E1A30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              pinController.dispose();
              Navigator.of(dialogCtx).pop();
            },
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin == ProviderCurationRules.adultUnlockPin) {
                pinController.dispose();
                Navigator.of(dialogCtx).pop();
                Get.toNamed(screenAdultContent);
              } else {
                pinController.dispose();
                Navigator.of(dialogCtx).pop();
                Get.snackbar(
                  'Access Denied',
                  'Incorrect PIN.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFF2D0A0A),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text("Unlock"),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGreetingSection() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final username = state is AuthSuccess
            ? (state.user.userInfo?.username ?? 'Premium Member')
            : 'Premium Member';
        final expDateStr = state is AuthSuccess
            ? 'Exp: ${expirationDate(state.user.userInfo?.expDate)}'
            : 'Active Account';
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFFFC107).withOpacity(0.08),
                      child: const Icon(Icons.person, color: Color(0xFFFFC107), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, $username",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  expDateStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Obvious Search Trigger button in Header
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                onPressed: () => Get.to(() => const MobileSearchScreen()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalTvChannelsRow() {
    final activeMarket = LocalMarketService.getActiveMarket();
    final profile = UserPreferenceProfile.load();
    if (!profile.locationFeatureEnabled || activeMarket == null) return const SizedBox();

    final localChannels = LocalMarketService.getLocalChannelsForCategory(
      categoryKey: 'all',
      market: activeMarket,
      playlist: _allLiveChannelsForMatching,
    );

    if (localChannels.isEmpty) return const SizedBox();

    final favState = context.watch<FavoritesCubit>().state;

    return HorizontalPosterRows(
      title: activeMarket.id == 'atlanta_ga' ? "Atlanta Local Channels" : "Local TV Near You",
      titleIcon: Icons.location_on_rounded,
      titleIconColor: Colors.amber,
      itemCount: localChannels.length > 10 ? 10 : localChannels.length,
      aspect: PosterAspect.landscape,
      itemBuilder: (context, index) {
        final channel = localChannels[index];
        final isFav = favState.lives.any((l) => l.streamId == channel.streamId);
        return PosterCard(
          title: channel.name ?? 'Local Feed',
          imageUrl: channel.streamIcon,
          aspect: PosterAspect.landscape,
          isLive: true,
          isFavorite: isFav,
          onLongPress: () {
            context.read<FavoritesCubit>().addLive(channel, isAdd: !isFav);
            _showSuccessToast(isFav ? "Removed from Favourites" : "Added to Favourites");
          },
          onTap: () {
            UserBehaviorService.trackClick(channel.streamId ?? '', channel.categoryId);
            _onLiveChannelTap(channel);
          },
        );
      },
      onSeeAllTap: () => Get.to(() => LocalTvScreen(
        allLiveChannels: _allLiveChannelsForMatching,
        onPlayChannel: (ch) => _onLiveChannelTap(ch),
      )),
    );
  }

  Widget _buildBrowseEntryPoints() {
    final activeMarket = LocalMarketService.getActiveMarket();
    final profile = UserPreferenceProfile.load();
    final showLocal = profile.locationFeatureEnabled && activeMarket != null;

    final entries = [
      if (showLocal)
        {"title": "Local TV", "icon": Icons.location_on_rounded, "isLocal": true, "color": Colors.amber},
      {"title": "All Channels • 20,000+", "icon": Icons.live_tv_rounded, "isLocal": false, "mode": BrowseMode.live, "color": const Color(0xFFFFC107)},
      {"title": "All Movies", "icon": Icons.movie_outlined, "isLocal": false, "mode": BrowseMode.movies, "color": const Color(0xFFFF416C)},
      {"title": "All Series", "icon": Icons.video_library_outlined, "isLocal": false, "mode": BrowseMode.series, "color": const Color(0xFF00C6FF)},
      {"title": "Browse Countries", "icon": Icons.flag_outlined, "isLocal": false, "mode": BrowseMode.countries, "color": Colors.tealAccent},
      {"title": "Browse Languages", "icon": Icons.language_outlined, "isLocal": false, "mode": BrowseMode.languages, "color": Colors.purpleAccent},
      {"title": "Categories", "icon": Icons.dashboard_customize_outlined, "isLocal": false, "mode": BrowseMode.categories, "color": Colors.pinkAccent},
    ];

    List<Color> getCardGradient(String title) {
      final cleanTitle = title.toLowerCase();
      if (cleanTitle.contains('channels')) {
        return [const Color(0xFFCC181E), const Color(0xFF7A0F12)]; // Red
      } else if (cleanTitle.contains('movies')) {
        return [const Color(0xFFE65100), const Color(0xFFB33600)]; // Orange
      } else if (cleanTitle.contains('series')) {
        return [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]; // Green
      } else if (cleanTitle.contains('countries')) {
        return [const Color(0xFF1976D2), const Color(0xFF0D47A1)]; // Blue
      } else if (cleanTitle.contains('languages')) {
        return [const Color(0xFF7B1FA2), const Color(0xFF4A148C)]; // Purple
      } else if (cleanTitle.contains('categories')) {
        return [const Color(0xFF00796B), const Color(0xFF004D40)]; // Teal
      } else if (cleanTitle.contains('local')) {
        return [const Color(0xFFFFB300), const Color(0xFFB58900)]; // Gold/Amber
      }
      return [const Color(0xFF231C35), const Color(0xFF13101E)];
    }

    Color getCardAccent(String title) {
      final cleanTitle = title.toLowerCase();
      if (cleanTitle.contains('channels')) {
        return const Color(0xFFCC181E);
      } else if (cleanTitle.contains('movies')) {
        return const Color(0xFFFF5722);
      } else if (cleanTitle.contains('series')) {
        return const Color(0xFF2E7D32);
      } else if (cleanTitle.contains('countries')) {
        return const Color(0xFF1976D2);
      } else if (cleanTitle.contains('languages')) {
        return const Color(0xFF7B1FA2);
      } else if (cleanTitle.contains('categories')) {
        return const Color(0xFF00796B);
      } else if (cleanTitle.contains('local')) {
        return const Color(0xFFFFC107);
      }
      return Colors.amber;
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          final title = item["title"] as String;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                if (item["isLocal"] == true) {
                  Get.to(() => LocalTvScreen(
                        allLiveChannels: _allLiveChannelsForMatching,
                        onPlayChannel: (ch) => _onLiveChannelTap(ch),
                      ));
                } else {
                  Get.to(() => AllContentScreen(initialMode: item["mode"] as BrowseMode));
                }
              },
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: getCardGradient(title),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: getCardAccent(title).withOpacity(0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: getCardAccent(title).withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item["icon"] as IconData,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavSubscreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (_currentNavIndex) {
        case 1:
          Get.to(() => const MobileSearchScreen());
          break;
        case 2:
          Get.toNamed(screenFavourite);
          break;
        case 3:
          Get.toNamed(screenCatchUp);
          break;
        case 4:
          Get.toNamed(screenSettings);
          break;
      }
      setState(() {
        _currentNavIndex = 0;
      });
    });
    return _buildHomeWatchScreen();
  }

  void _onLiveChannelTap(ChannelLive channel) async {
    if (channel.directSource != null && channel.directSource!.isNotEmpty) {
      final streamUrl = channel.directSource!;
      StreamLauncher.openStreamWithBrandedLoading(
        context: context,
        streamUrl: streamUrl,
        playerBuilder: () => MoviePlayerScreen(link: streamUrl, title: channel.name ?? 'Stream'),
      );
    } else if (channel.streamId != null) {
      final streamUrl = await PlaybackUrlBuilder.buildLiveUrl(channel.streamId!);
      if (streamUrl.isNotEmpty) {
        // Track play start
        UserBehaviorService.trackPlay(channel.streamId ?? '', channel.categoryId, 0);
        
        StreamLauncher.openStreamWithBrandedLoading(
          context: context,
          streamUrl: streamUrl,
          playerBuilder: () => MoviePlayerScreen(link: streamUrl, title: channel.name ?? 'Stream'),
        );
      }
    }
  }

  void _onHeroPlayTap(ChannelMovie movie) async {
    if (movie.customSid == 'series') {
      Get.to(() => SerieContent(channelSerie: ChannelSerie(seriesId: movie.streamId, name: movie.name, cover: movie.streamIcon), videoId: movie.streamId ?? ''));
    } else if (movie.customSid == 'live') {
      if (movie.streamId != null) {
        final streamUrl = await PlaybackUrlBuilder.buildLiveUrl(movie.streamId!);
        if (streamUrl.isNotEmpty) {
          // Track play start
          UserBehaviorService.trackPlay(movie.streamId ?? '', movie.categoryId, 0);

          StreamLauncher.openStreamWithBrandedLoading(
            context: context,
            streamUrl: streamUrl,
            playerBuilder: () => MoviePlayerScreen(link: streamUrl, title: movie.name ?? 'Stream'),
          );
        }
      }
    } else {
      if (movie.streamId != null) {
        final streamUrl = await PlaybackUrlBuilder.buildMovieUrl(movie.streamId!, containerExtension: movie.containerExtension);
        if (streamUrl.isNotEmpty) {
          // Track play start
          UserBehaviorService.trackPlay(movie.streamId ?? '', movie.categoryId, 0);

          StreamLauncher.openStreamWithBrandedLoading(
            context: context,
            streamUrl: streamUrl,
            playerBuilder: () => MoviePlayerScreen(link: streamUrl, title: movie.name ?? 'Stream'),
          );
        }
      }
    }
  }

  void _onHeroInfoTap(ChannelMovie movie) {
    if (movie.customSid == 'series') {
      Get.to(() => SerieContent(channelSerie: ChannelSerie(seriesId: movie.streamId, name: movie.name, cover: movie.streamIcon), videoId: movie.streamId ?? ''));
    } else if (movie.customSid == 'live') {
      _onHeroPlayTap(movie);
    } else {
      _showMovieDetailSheet(movie);
    }
  }

  void _onMoviePlayTap(ChannelMovie movie) async {
    if (movie.streamId != null) {
      final streamUrl = await PlaybackUrlBuilder.buildMovieUrl(movie.streamId!, containerExtension: movie.containerExtension);
      if (streamUrl.isNotEmpty) {
        // Track play start
        UserBehaviorService.trackPlay(movie.streamId ?? '', movie.categoryId, 0);

        StreamLauncher.openStreamWithBrandedLoading(
          context: context,
          streamUrl: streamUrl,
          playerBuilder: () => MoviePlayerScreen(link: streamUrl, title: movie.name ?? 'Stream'),
        );
      }
    }
  }

  void _showMovieDetailSheet(ChannelMovie movie) {
    Get.to(
      () => MobileDetailScreen(
        movie: movie,
        onPlayTap: () {
          Get.back();
          _onMoviePlayTap(movie);
        },
      ),
    );
  }
}
