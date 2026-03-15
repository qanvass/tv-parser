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

  // 0 = action buttons, 1 = seasons, 2 = episodes
  int _panel = 0;
  int _selectedButton = 0;
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
        setState(() {
          _serieDetails = serie;
          _hasTrailer =
              serie.info?.youtubeTrailer != null &&
              serie.info!.youtubeTrailer!.isNotEmpty;
        });
        _initSeasonsEpisodes(serie);
      }
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
    _pageScroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
    final target = (idx * itemW).clamp(0.0, _seasonScroll.position.maxScrollExtent);
    _seasonScroll.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  void _scrollEpisodeTo(int idx) {
    if (!_episodeScroll.hasClients) return;
    const itemW = 162.0;
    final target = (idx * itemW).clamp(0.0, _episodeScroll.position.maxScrollExtent);
    _episodeScroll.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_isBackFocused) return KeyEventResult.handled;
      if (_panel > 0) {
        final prev = _panel - 1;
        setState(() => _panel = prev);
        if (prev == 0) _scrollPageToTop();
        if (prev == 1) _scrollSeasonTo(_seasonIdx);
      } else {
        setState(() => _isBackFocused = true);
        _scrollPageToTop();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      if (_isBackFocused) {
        setState(() { _isBackFocused = false; _panel = 0; });
        _scrollPageToTop();
      } else {
        final maxPanel = _seasons.isNotEmpty ? 2 : 0;
        if (_panel < maxPanel) {
          final next = _panel + 1;
          setState(() => _panel = next);
          if (next == 1 || next == 2) _scrollPageToBottom();
          if (next == 1) _scrollSeasonTo(_seasonIdx);
          else if (next == 2) _scrollEpisodeTo(_episodeIdx);
        }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_isBackFocused) return KeyEventResult.handled;
      if (_panel == 0 && _selectedButton > 0) {
        setState(() => _selectedButton--);
      } else if (_panel == 1 && _seasonIdx > 0) {
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
      if (_isBackFocused) return KeyEventResult.handled;
      final maxBtn = _hasTrailer ? 1 : 0;
      if (_panel == 0 && _selectedButton < maxBtn) {
        setState(() => _selectedButton++);
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
    if (_selectedButton == 0 && _hasTrailer && _serieDetails != null) {
      showDialog(
        context: context,
        builder: (_) => DialogTrailerYoutube(
          thumb: _serieDetails!.info!.backdropPath != null &&
                  _serieDetails!.info!.backdropPath!.isNotEmpty
              ? _serieDetails!.info!.backdropPath!.first
              : null,
          trailer: _serieDetails!.info!.youtubeTrailer ?? "",
        ),
      );
    } else {
      final favState = context.read<FavoritesCubit>().state;
      final isLiked = favState.series.any((s) => s.seriesId == widget.channelSerie.seriesId);
      context.read<FavoritesCubit>().addSerie(widget.channelSerie, isAdd: !isLiked);
    }
  }

  void _playEpisode() {
    if (_episodes.isEmpty || _episodeIdx >= _episodes.length) return;
    final model = _episodes[_episodeIdx];
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final link =
        "${authState.user.serverInfo!.serverUrl}/series/${authState.user.userInfo!.username}/${authState.user.userInfo!.password}/${model.id}.${model.containerExtension}";

    Get.to(() => FullVideoScreen(link: link, title: model.title ?? ""))?.then((slider) {
      if (slider != null) {
        final watchModel = WatchingModel(
          sliderValue: slider[0],
          durationStrm: slider[1],
          stream: link,
          title: model.title ?? "",
          image: model.info?.movieImage ?? _serieDetails?.info?.cover ?? "",
          streamId: model.id.toString(),
        );
        context.read<WatchingCubit>().addSerie(watchModel);
      }
    });
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kColorPrimary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: kColorHint, fontSize: 13, fontWeight: FontWeight.bold),
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
    return Scaffold(
      body: Focus(
        focusNode: _navFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: FutureBuilder<SerieDetails?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: kDecorBackground,
                child: const Center(child: CircularProgressIndicator(color: kColorPrimary)),
              );
            }
            if (!snapshot.hasData) {
              return Container(
                decoration: kDecorBackground,
                child: const Center(
                  child: Text("Could not load data", style: TextStyle(color: Colors.white)),
                ),
              );
            }

            final serie = snapshot.data!;

            return Stack(
              children: [
                CardMovieImagesBackground(listImages: serie.info!.backdropPath ?? []),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xEE000000)],
                      stops: [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 25, left: 10, right: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: Get.back,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isBackFocused ? kColorPrimary : Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isBackFocused ? kColorFocus : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: const Icon(FontAwesomeIcons.chevronLeft, color: Colors.white, size: 18),
                        ),
                      ),
                      // Main content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _pageScroll,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              // Cover + info + plot + buttons (padded)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: serie.info!.cover ?? "",
                                            width: 140,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(
                                              width: 140,
                                              height: 200,
                                              color: kColorCardLight,
                                              child: const Icon(FontAwesomeIcons.tv, color: kColorHint, size: 40),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                              _buildInfoRow(icon: FontAwesomeIcons.clapperboard, label: 'Director', value: serie.info!.director ?? ""),
                                              const SizedBox(height: 10),
                                              _buildInfoRow(icon: FontAwesomeIcons.calendarDay, label: 'Release', value: serie.info!.releaseDate ?? ""),
                                              const SizedBox(height: 10),
                                              _buildInfoRow(icon: FontAwesomeIcons.film, label: 'Genre', value: serie.info!.genre ?? ""),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'PLOT',
                                      style: TextStyle(color: kColorHint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      serie.info!.plot ?? "",
                                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildButtons(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Seasons + Episodes — full width, no horizontal padding
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

  Widget _buildButtons() {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favState) {
        final isLiked = favState.series.any((s) => s.seriesId == widget.channelSerie.seriesId);
        final favBtnIdx = _hasTrailer ? 1 : 0;
        return Row(
          children: [
            if (_hasTrailer) ...[
              Expanded(
                child: _SerieButton(
                  label: "TRAILER",
                  icon: FontAwesomeIcons.youtube,
                  isSelected: _panel == 0 && _selectedButton == 0,
                  onTap: () {
                    setState(() { _panel = 0; _selectedButton = 0; });
                    _handleButtonPress();
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
            _SerieButton(
              label: isLiked ? "UNFAV" : "FAV",
              icon: isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
              isSelected: _panel == 0 && _selectedButton == favBtnIdx,
              isFavorite: true,
              onTap: () {
                setState(() { _panel = 0; _selectedButton = favBtnIdx; });
                _handleButtonPress();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeasonsEpisodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seasons label
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'SEASONS',
            style: TextStyle(color: kColorHint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        // Seasons horizontal list
        SizedBox(
          height: 36,
          child: ListView.builder(
            controller: _seasonScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: _seasons.length,
            itemBuilder: (context, idx) {
              final isSelected = idx == _seasonIdx;
              final isFocused = isSelected && _panel == 1;
              return GestureDetector(
                onTap: () {
                  setState(() { _seasonIdx = idx; _panel = 1; });
                  _loadEpisodes(_seasons[idx]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? kColorPrimary : kColorPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFocused ? kColorFocus : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isFocused
                        ? [BoxShadow(color: kColorFocus.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                        : [],
                  ),
                  child: Text(
                    "Season ${_seasons[idx]}",
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Episodes label
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'EPISODES',
            style: TextStyle(color: kColorHint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        // Episodes horizontal list
        if (_episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 12, bottom: 12),
            child: Text("No episodes available", style: TextStyle(color: kColorHint, fontSize: 13)),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              controller: _episodeScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: _episodes.length,
              itemBuilder: (context, idx) {
                final ep = _episodes[idx];
                final isSelected = idx == _episodeIdx;
                final isFocused = isSelected && _panel == 2;
                return GestureDetector(
                  onTap: () {
                    setState(() { _episodeIdx = idx; _panel = 2; });
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
                          ? [BoxShadow(color: kColorFocus.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: CachedNetworkImage(
                            imageUrl: ep.info?.movieImage ?? _serieDetails?.info?.cover ?? "",
                            width: 150,
                            height: 100,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 150,
                              height: 100,
                              color: kColorCardDark,
                              child: const Icon(FontAwesomeIcons.tv, color: kColorHint),
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
                                    color: isSelected ? kColorPrimary : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ep.title ?? "Episode ${idx + 1}",
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
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

class _SerieButton extends StatelessWidget {
  const _SerieButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isFavorite = false,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [kColorPrimary, kColorPrimaryDark])
              : isFavorite
              ? LinearGradient(colors: [Colors.red.withValues(alpha: 0.25), Colors.red.withValues(alpha: 0.25)])
              : LinearGradient(colors: [kColorPrimary.withValues(alpha: 0.2), kColorPrimaryDark.withValues(alpha: 0.2)]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kColorFocus : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: kColorFocus.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
