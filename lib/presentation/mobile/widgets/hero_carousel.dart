import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pod_player/pod_player.dart';
import '../../../repository/models/channel_movie.dart';
import '../../../repository/api/hero_content_service.dart';

class HeroCarousel extends StatefulWidget {
  final List<HeroCarouselItem> movies;
  final Function(ChannelMovie) onPlayTap;
  final Function(ChannelMovie) onInfoTap;

  const HeroCarousel({
    super.key,
    required this.movies,
    required this.onPlayTap,
    required this.onInfoTap,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Active trailer preview player properties
  PodPlayerController? _activeController;
  Timer? _debounceTimer;
  bool _isPlayerInitialized = false;

  @override
  void initState() {
    super.initState();
    // Start playback for first item if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.movies.isNotEmpty) {
        _debouncedPreviewStart(0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the movies list changes, reset and trigger for the current page
    if (widget.movies.length != oldWidget.movies.length ||
        (widget.movies.isNotEmpty && oldWidget.movies.isNotEmpty && widget.movies.first.id != oldWidget.movies.first.id)) {
      _stopActivePlayer();
      _debouncedPreviewStart(_currentPage);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _stopActivePlayer();
    _pageController.dispose();
    super.dispose();
  }

  void _debouncedPreviewStart(int index) {
    _debounceTimer?.cancel();
    _stopActivePlayer();

    final readyMovies = widget.movies.where((movie) => movie.isHeroReady).toList();

    if (index < 0 || index >= readyMovies.length) {
      return;
    }

    final item = readyMovies[index];
    if (item.previewType != HeroPreviewType.trailer || item.trailerYoutubeId == null) {
      return;
    }

    // Debounce player creation by 400ms to keep page swiping fast and fluid
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _startTrailerPlayer(index, item.trailerYoutubeId!);
    });
  }

  void _stopActivePlayer() {
    if (_activeController != null) {
      final oldController = _activeController!;
      _activeController = null;
      _isPlayerInitialized = false;
      // Dispose asynchronously off the main thread
      Future.microtask(() => oldController.dispose());
    }
  }

  void _startTrailerPlayer(int index, String youtubeId) {
    if (!mounted || index != _currentPage) return;

    _stopActivePlayer();

    final controller = PodPlayerController(
      playVideoFrom: PlayVideoFrom.youtube('https://youtu.be/$youtubeId'),
      podPlayerConfig: const PodPlayerConfig(
        autoPlay: true,
        isLooping: true,
      ),
    )..mute();

    _activeController = controller;

    controller.initialise().then((_) {
      if (mounted && index == _currentPage && _activeController == controller) {
        setState(() {
          _isPlayerInitialized = true;
        });
      } else {
        controller.dispose();
      }
    }).catchError((err) {
      debugPrint("[HERO_CAROUSEL] Muted trailer player initialize error: $err");
      if (mounted && _activeController == controller) {
        _stopActivePlayer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter and render only ready items
    final readyMovies = widget.movies.where((m) => m.isHeroReady).toList();

    if (readyMovies.isEmpty) {
      return _buildSkeletonPlaceholder();
    }

    return SizedBox(
      height: 380,
      child: Stack(
        children: [
          // 1. Sliding PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _isPlayerInitialized = false;
              });
              _debouncedPreviewStart(index);
            },
            itemCount: readyMovies.length,
            itemBuilder: (context, index) {
              final movie = readyMovies[index];
              return _buildCarouselItem(movie, index);
            },
          ),

          // 2. Bottom-only readability and fade-out gradient (lower 25-35% of the hero)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 0.72, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Left-side Horizontal Text Scrim for Title/CTA Readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.black.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 4. Top Vignette Overlay for status bar/header blending
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 5. Page Indicator Dots
          Positioned(
            bottom: 24,
            left: 20,
            child: Row(
              children: List.generate(
                readyMovies.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _currentPage == index ? 22 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).primaryColor
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(HeroCarouselItem movie, int index) {
    final title = movie.title;
    final imageUrl = movie.imageUrl ?? '';
    final rating = movie.rawMovie.rating ?? '8.5';

    String tagText = "FEATURED MOVIE";
    Color tagColor = Colors.amber.shade700;

    if (movie.isLive) {
      final nameLower = title.toLowerCase();
      if (nameLower.contains('news') || nameLower.contains('cnn') || nameLower.contains('bbc') || nameLower.contains('cnbc') || nameLower.contains('msnbc')) {
        tagText = "LIVE NEWS";
        tagColor = Colors.redAccent;
      } else if (nameLower.contains('sport') || nameLower.contains('espn') || nameLower.contains('fox') || nameLower.contains('bein') || nameLower.contains('sky') || nameLower.contains('ufc') || nameLower.contains('boxing') || nameLower.contains('wwe') || nameLower.contains('cup')) {
        tagText = "LIVE SPORTS";
        tagColor = Colors.orange.shade800;
      } else {
        tagText = "LIVE EVENT";
        tagColor = Colors.teal;
      }
    }

    return GestureDetector(
      onTap: () {
        if (movie.isLive) {
          widget.onPlayTap(movie.rawMovie);
        } else {
          widget.onInfoTap(movie.rawMovie);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background static cover image
          imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  fadeInDuration: const Duration(milliseconds: 300),
                  placeholder: (context, url) => _buildImageSkeleton(),
                  errorWidget: (context, url, error) => _buildFallbackCover(title),
                )
              : _buildFallbackCover(title),

          // Autoplay Video Trailer Overlay (Muted full-bleed using FittedBox)
          if (_currentPage == index && _isPlayerInitialized && _activeController != null)
            Positioned.fill(
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 16,
                    height: 9,
                    child: PodVideoPlayer(
                      controller: _activeController!,
                      alwaysShowProgressBar: false,
                      podProgressBarConfig: const PodProgressBarConfig(
                        playingBarColor: Colors.transparent,
                        circleHandlerColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Text & Action Buttons Overlay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Movie Rating Badge & VOD Tag
                Row(
                  children: [
                    if (!movie.isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "LIVE",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tagColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tagText,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Glassmorphic Buttons Row
                Row(
                  children: [
                    // Play Action Button (Premium solid rounded)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () => widget.onPlayTap(movie.rawMovie),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                      label: const Text(
                        "Play Now",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Info Action Button (Glassmorphic)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () => widget.onInfoTap(movie.rawMovie),
                      icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                      label: const Text(
                        "Info",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Lift above indicators
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSkeleton() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF141416), Color(0xFF222226), Color(0xFF141416)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Colors.white10, strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildFallbackCover(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1A2C), Color(0xFF0F0B18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_filter_rounded, size: 48, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonPlaceholder() {
    return Container(
      height: 380,
      width: double.infinity,
      color: const Color(0xFF0F0F10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageSkeleton(),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 80, height: 16, color: Colors.white10),
                const SizedBox(height: 10),
                Container(width: 240, height: 28, color: Colors.white10),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(width: 120, height: 42, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(30))),
                    const SizedBox(width: 10),
                    Container(width: 90, height: 42, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(30))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
