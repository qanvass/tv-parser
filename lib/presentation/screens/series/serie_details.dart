part of '../screens.dart';

class SerieContent extends StatefulWidget {
  const SerieContent({
    super.key,
    required this.videoId,
    required this.channelSerie,
  });

  final String videoId;
  final ChannelSerie channelSerie;

  @override
  State<SerieContent> createState() => _SerieContentState();
}

class _SerieContentState extends State<SerieContent> {
  late Future<SerieDetails?> _future;
  SerieDetails? _serieDetails;
  final _navFocus = FocusNode();

  // Left column buttons: -1 = none, 1 = Trailer, 2 = Fav (with trailer) / 1 = Fav (no trailer)
  // Right panels: 1 = seasons, 2 = episodes
  int _selectedButton = -1;
  int _panel = 0; // 0 = left column active, 1 = seasons, 2 = episodes

  int _seasonIdx = 0;
  int _episodeIdx = 0;

  bool _isBackFocused = false;
  bool _hasTrailer = false;

  List<String> _seasons = [];
  List<Episode> _episodes = [];

  final _pageScroll = ScrollController();
  final _seasonScroll = ScrollController();
  final _episodeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = IpTvApi.getSerieDetails(widget.videoId);
    _future.then((serie) {
      if (mounted && serie != null) {
        final hasTrailer =
            serie.info?.youtubeTrailer != null &&
            serie.info!.youtubeTrailer!.isNotEmpty;
        setState(() {
          _serieDetails = serie;
          _hasTrailer = hasTrailer;
          _selectedButton = 1; // default focus: Trailer or Fav
        });
        _initSeasonsEpisodes(serie);
      }
    });
  }

  void _reload() {
    setState(() {
      _serieDetails = null;
      _selectedButton = -1;
      _isBackFocused = false;
      _hasTrailer = false;
      _seasons = [];
      _episodes = [];
      _seasonIdx = 0;
      _episodeIdx = 0;
      _panel = 0;
      _future = IpTvApi.getSerieDetails(widget.videoId);
      _future.then((serie) {
        if (mounted && serie != null) {
          final hasTrailer =
              serie.info?.youtubeTrailer != null &&
              serie.info!.youtubeTrailer!.isNotEmpty;
          setState(() {
            _serieDetails = serie;
            _hasTrailer = hasTrailer;
            _selectedButton = 1;
          });
          _initSeasonsEpisodes(serie);
        }
      });
    });
  }

  @override
  void dispose() {
    _navFocus.dispose();
    _pageScroll.dispose();
    _seasonScroll.dispose();
    _episodeScroll.dispose();
    super.dispose();
  }

  void _initSeasonsEpisodes(SerieDetails serie) {
    if (_seasons.isNotEmpty) return;
    if (serie.episodes != null && serie.episodes!.isNotEmpty) {
      _seasons = serie.episodes!.keys.toList();
      if (_seasons.isNotEmpty) _loadEpisodes(_seasons[0]);
    }
  }

  void _loadEpisodes(String season) {
    if (_serieDetails == null) return;
    final eps = _serieDetails!.episodes![season] ?? [];
    setState(() {
      _episodes = eps.whereType<Episode>().toList();
      _episodeIdx = 0;
    });
    if (_episodeScroll.hasClients) _episodeScroll.jumpTo(0);
  }

  void _scrollPageToTop() {
    if (!_pageScroll.hasClients) return;
    _pageScroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollPageToBottom() {
    if (!_pageScroll.hasClients) return;
    _pageScroll.animateTo(
      _pageScroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollSeasonTo(int idx) {
    if (!_seasonScroll.hasClients) return;
    const itemW = 130.0;
    final target = (idx * itemW).clamp(
      0.0,
      _seasonScroll.position.maxScrollExtent,
    );
    _seasonScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _scrollEpisodeTo(int idx) {
    if (!_episodeScroll.hasClients) return;
    const itemW = 162.0;
    final target = (idx * itemW).clamp(
      0.0,
      _episodeScroll.position.maxScrollExtent,
    );
    _episodeScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  // Layout:
  //  Left column   |  Right content
  //  [Back]        |  [Cover + info + plot]
  //  [Spacer]      |  [Seasons row]
  //  [Trailer?]    |  [Episodes row]
  //  [Fav]         |
  //
  // Up/Down → navigate within left column / right panels
  // Down from Fav → seasons (panel 1)
  // Up from seasons → back to left column (Fav)
  // Right from left column → seasons (panel 1)
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final favIdx = _hasTrailer ? 2 : 1;

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_isBackFocused) return KeyEventResult.handled;
      if (_panel == 0) {
        // Within left column: Fav → Trailer → Back
        if (_selectedButton == favIdx && _hasTrailer) {
          setState(() => _selectedButton = 1);
        } else {
          setState(() {
            _isBackFocused = true;
            _selectedButton = -1;
          });
          _scrollPageToTop();
        }
      } else if (_panel == 1) {
        // Seasons → left column (Fav)
        setState(() {
          _panel = 0;
          _selectedButton = favIdx;
        });
        _scrollPageToTop();
      } else if (_panel == 2) {
        // Episodes → Seasons
        setState(() => _panel = 1);
        _scrollSeasonTo(_seasonIdx);
        _scrollPageToBottom();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      if (_isBackFocused) {
        // Back → first left column button (Trailer or Fav)
        setState(() {
          _isBackFocused = false;
          _panel = 0;
          _selectedButton = 1;
        });
      } else if (_panel == 0) {
        if (_selectedButton == 1 && _hasTrailer) {
          // Trailer → Fav
          setState(() => _selectedButton = favIdx);
        } else {
          // Fav (bottom of left column) → seasons
          setState(() {
            _panel = 1;
            _selectedButton = -1;
          });
          _scrollPageToBottom();
          _scrollSeasonTo(_seasonIdx);
        }
      } else if (_panel == 1) {
        // Seasons → Episodes
        setState(() => _panel = 2);
        _scrollEpisodeTo(_episodeIdx);
        _scrollPageToBottom();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_isBackFocused || _panel == 0) return KeyEventResult.handled;
      if (_panel == 1 && _seasonIdx > 0) {
        setState(() => _seasonIdx--);
        _loadEpisodes(_seasons[_seasonIdx]);
        _scrollSeasonTo(_seasonIdx);
      } else if (_panel == 2 && _episodeIdx > 0) {
        setState(() => _episodeIdx--);
        _scrollEpisodeTo(_episodeIdx);
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowRight) {
      if (_isBackFocused) {
        // Back → seasons
        setState(() {
          _isBackFocused = false;
          _panel = 1;
          _selectedButton = -1;
        });
        _scrollPageToBottom();
        _scrollSeasonTo(_seasonIdx);
        return KeyEventResult.handled;
      }
      if (_panel == 0) {
        // Left column → seasons
        setState(() {
          _panel = 1;
          _selectedButton = -1;
        });
        _scrollPageToBottom();
        _scrollSeasonTo(_seasonIdx);
      } else if (_panel == 1 && _seasonIdx < _seasons.length - 1) {
        setState(() => _seasonIdx++);
        _loadEpisodes(_seasons[_seasonIdx]);
        _scrollSeasonTo(_seasonIdx);
      } else if (_panel == 2 && _episodeIdx < _episodes.length - 1) {
        setState(() => _episodeIdx++);
        _scrollEpisodeTo(_episodeIdx);
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_isBackFocused) {
        Get.back();
      } else if (_panel == 0) {
        _handleButtonPress();
      } else if (_panel == 2) {
        _playEpisode();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleButtonPress() {
    if (_selectedButton == 1 && _hasTrailer && _serieDetails != null) {
      showDialog(
        context: context,
        builder: (_) => DialogTrailerYoutube(
          thumb:
              _serieDetails!.info!.backdropPath != null &&
                  _serieDetails!.info!.backdropPath!.isNotEmpty
              ? _serieDetails!.info!.backdropPath!.first
              : null,
          trailer: _serieDetails!.info!.youtubeTrailer ?? "",
          title: _serieDetails!.info?.name ?? widget.channelSerie.name,
        ),
      );
    } else {
      final favState = context.read<FavoritesCubit>().state;
      final isLiked = favState.series.any(
        (s) => s.seriesId == widget.channelSerie.seriesId,
      );
      context.read<FavoritesCubit>().addSerie(
        widget.channelSerie,
        isAdd: !isLiked,
      );
    }
  }

  void _playEpisode() {
    if (_episodes.isEmpty || _episodeIdx >= _episodes.length) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    Get.to(
      () => SeriesPlayerScreen(
        episodes: _episodes,
        initialIdx: _episodeIdx,
        serverUrl: authState.user.serverInfo!.serverUrl ?? "",
        username: authState.user.userInfo!.username ?? "",
        password: authState.user.userInfo!.password ?? "",
        seriesCover: _serieDetails?.info?.cover ?? '',
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kColorPrimary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: kColorHint,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final favIdx = _hasTrailer ? 2 : 1;

    return Scaffold(
      body: Focus(
        focusNode: _navFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: FutureBuilder<SerieDetails?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _DetailsLoadingState(
                title: widget.channelSerie.name ?? '',
              );
            }
            if (!snapshot.hasData) {
              return _DetailsErrorState(onBack: Get.back, onReload: _reload);
            }

            final serie = snapshot.data!;

            return Stack(
              children: [
                CardMovieImagesBackground(
                  listImages: serie.info!.backdropPath ?? [],
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xCC000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xEE000000),
                      ],
                      stops: [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 25, left: 10, right: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: Back + Trailer + Fav
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          spacing: 5,
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: Get.back,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isBackFocused
                                      ? kColorPrimary
                                      : Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isBackFocused
                                        ? kColorFocus
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(FontAwesomeIcons.chevronLeft.data,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Trailer button
                            if (_hasTrailer)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _panel = 0;
                                    _selectedButton = 1;
                                  });
                                  _handleButtonPress();
                                },
                                child: _SideButton(
                                  icon: FontAwesomeIcons.youtube.data,
                                  isSelected:
                                      _selectedButton == 1 && _panel == 0,
                                ),
                              ),
                            // Fav button
                            BlocBuilder<FavoritesCubit, FavoritesState>(
                              builder: (context, favState) {
                                final isLiked = favState.series.any(
                                  (s) =>
                                      s.seriesId ==
                                      widget.channelSerie.seriesId,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _panel = 0;
                                      _selectedButton = favIdx;
                                    });
                                    _handleButtonPress();
                                  },
                                  child: _SideButton(
                                    icon: isLiked
                                        ? FontAwesomeIcons.solidHeart.data
                                        : FontAwesomeIcons.heart.data,
                                    isSelected:
                                        _selectedButton == favIdx &&
                                        _panel == 0,
                                    isFavorite: true,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Right content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _pageScroll,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              // Cover + info + plot (padded)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: serie.info!.cover ?? "",
                                            width: 140,
                                            height: 200,
                                            memCacheWidth: 300,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                  width: 140,
                                                  height: 200,
                                                  color: kColorCardLight,
                                                  child: Icon(FontAwesomeIcons.tv.data,
                                                    color: kColorHint,
                                                    size: 40,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                serie.info!.name ?? "",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons.clapperboard.data,
                                                label: 'Director',
                                                value:
                                                    serie.info!.director ?? "",
                                              ),
                                              const SizedBox(height: 10),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons.calendarDay.data,
                                                label: 'Release',
                                                value:
                                                    serie.info!.releaseDate ??
                                                    "",
                                              ),
                                              SizedBox(height: 10),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons.film.data,
                                                label: 'Genre',
                                                value: serie.info!.genre ?? "",
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'PLOT',
                                      style: TextStyle(
                                        color: kColorHint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (serie.info!.plot != null &&
                                       serie.info!.plot!.isNotEmpty &&
                                       serie.info!.plot != "null" &&
                                       !serie.info!.plot!.toLowerCase().contains("iptv") &&
                                       !serie.info!.plot!.toLowerCase().contains("servicer"))
                                          ? serie.info!.plot!
                                          : "No description available for this title.",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Seasons + Episodes — full width
                              if (_seasons.isNotEmpty) _buildSeasonsEpisodes(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeasonsEpisodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'SEASONS',
            style: TextStyle(
              color: kColorHint,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.builder(
            controller: _seasonScroll,
            cacheExtent: 350.0,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: _seasons.length,
            itemBuilder: (context, idx) {
              final isSelected = idx == _seasonIdx;
              final isFocused = isSelected && _panel == 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _seasonIdx = idx;
                    _panel = 1;
                    _selectedButton = -1;
                  });
                  _loadEpisodes(_seasons[idx]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? kColorFocus
                        : isSelected
                        ? kColorPrimary.withValues(alpha: 0.25)
                        : kColorPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFocused
                          ? kColorFocus
                          : isSelected
                          ? kColorPrimary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isFocused ? 2 : 1,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: kColorFocus.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    "Season ${_seasons[idx]}",
                    style: TextStyle(
                      color: isFocused
                          ? Colors.white
                          : isSelected
                          ? kColorPrimary
                          : Colors.white38,
                      fontSize: 13,
                      fontWeight: isFocused || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'EPISODES',
            style: TextStyle(
              color: kColorHint,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 12, bottom: 12),
            child: Text(
              "No episodes available",
              style: TextStyle(color: kColorHint, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              controller: _episodeScroll,
              cacheExtent: 350.0,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: _episodes.length,
              itemBuilder: (context, idx) {
                final ep = _episodes[idx];
                final isSelected = idx == _episodeIdx;
                final isFocused = isSelected && _panel == 2;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _episodeIdx = idx;
                      _panel = 2;
                      _selectedButton = -1;
                    });
                    _playEpisode();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 150,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: kColorCardLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused
                            ? kColorFocus
                            : isSelected
                            ? kColorPrimary.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isFocused
                          ? [
                              BoxShadow(
                                color: kColorFocus.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: CachedNetworkImage(
                            imageUrl:
                                ep.info?.movieImage ??
                                _serieDetails?.info?.cover ??
                                "",
                            width: 150,
                            height: 100,
                            memCacheWidth: 300,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 150,
                              height: 100,
                              color: kColorCardDark,
                              child: Icon(FontAwesomeIcons.tv.data,
                                color: kColorHint,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "E${idx + 1}",
                                  style: TextStyle(
                                    color: isSelected
                                        ? kColorPrimary
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ep.title ?? "Episode ${idx + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.isSelected,
    this.isFavorite = false,
  });

  final IconData icon;
  final bool isSelected;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(colors: [kColorPrimary, kColorPrimaryDark])
            : isFavorite
            ? LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.25),
                  Colors.red.withValues(alpha: 0.25),
                ],
              )
            : LinearGradient(
                colors: [
                  kColorPrimary.withValues(alpha: 0.2),
                  kColorPrimaryDark.withValues(alpha: 0.2),
                ],
              ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? kColorFocus : Colors.transparent,
          width: 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: kColorFocus.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

// ─── Shared loading / error states for details screens ────────────────────────

class _DetailsLoadingState extends StatelessWidget {
  const _DetailsLoadingState({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kDecorBackground,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Icon(FontAwesomeIcons.chevronLeft.data,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: kColorPrimary,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsErrorState extends StatelessWidget {
  const _DetailsErrorState({required this.onBack, required this.onReload});
  final VoidCallback onBack;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kDecorBackground,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Icon(FontAwesomeIcons.chevronLeft.data,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(FontAwesomeIcons.circleExclamation.data,
                      color: Colors.white38,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Could not load content',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check your connection and try again',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: onBack,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FontAwesomeIcons.chevronLeft.data,
                                color: Colors.white70,
                                size: 12,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Go Back',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Reload button
                      GestureDetector(
                        onTap: onReload,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: kColorPrimary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: kColorPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FontAwesomeIcons.arrowsRotate.data,
                                color: kColorPrimary,
                                size: 12,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Try Again',
                                style: TextStyle(
                                  color: kColorPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
