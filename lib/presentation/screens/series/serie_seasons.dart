part of '../screens.dart';

class SerieSeasons extends StatefulWidget {
  const SerieSeasons({super.key, required this.serieDetails});
  final SerieDetails serieDetails;

  @override
  State<SerieSeasons> createState() => _SerieSeasonsState();
}

class _SerieSeasonsState extends State<SerieSeasons> {
  late SerieDetails _serieDetails;
  final _navFocus = FocusNode();

  int _selectedPanel = 0;
  int _seasonIdx = 0;
  int _episodeIdx = 0;

  List<String> _seasons = [];
  List<Episode> _episodes = [];

  final _seasonScroll = ScrollController();
  final _episodeScroll = ScrollController();

  bool _isBackFocused = false;

  @override
  void initState() {
    super.initState();
    _serieDetails = widget.serieDetails;
    _initSeasons();
  }

  void _initSeasons() {
    if (_serieDetails.episodes != null && _serieDetails.episodes!.isNotEmpty) {
      _seasons = _serieDetails.episodes!.keys.toList();
      if (_seasons.isNotEmpty) {
        _loadEpisodes(_seasons[0]);
      }
    }
  }

  void _loadEpisodes(String season) {
    final eps = _serieDetails.episodes![season] ?? [];
    setState(() {
      _episodes = eps.whereType<Episode>().toList();
      _episodeIdx = 0;
    });
    if (_episodeScroll.hasClients) {
      _episodeScroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _navFocus.dispose();
    _seasonScroll.dispose();
    _episodeScroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_selectedPanel == 0) {
        if (!_isBackFocused) {
          setState(() => _isBackFocused = true);
        }
      } else if (_selectedPanel == 1) {
        if (_seasonIdx > 0) {
          setState(() => _seasonIdx--);
          _loadEpisodes(_seasons[_seasonIdx]);
          _scrollTo(_seasonScroll, _seasonIdx);
        } else {
          setState(() => _selectedPanel = 0);
        }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      if (_isBackFocused) {
        setState(() {
          _isBackFocused = false;
          _selectedPanel = 0;
        });
      } else if (_selectedPanel == 0) {
        if (_seasons.isNotEmpty) {
          setState(() => _selectedPanel = 1);
        }
      } else if (_selectedPanel == 1) {
        if (_seasonIdx < _seasons.length - 1) {
          setState(() => _seasonIdx++);
          _loadEpisodes(_seasons[_seasonIdx]);
          _scrollTo(_seasonScroll, _seasonIdx);
        }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_selectedPanel == 1) {
        if (_seasonIdx > 0) {
          setState(() => _seasonIdx--);
          _loadEpisodes(_seasons[_seasonIdx]);
          _scrollTo(_seasonScroll, _seasonIdx);
        } else {
          setState(() => _selectedPanel = 0);
        }
      } else if (_selectedPanel == 2) {
        if (_episodeIdx > 0) {
          setState(() => _episodeIdx--);
          _scrollEpisodeTo(_episodeIdx);
        }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowRight) {
      if (_selectedPanel == 0) {
        if (_seasons.isNotEmpty) {
          setState(() => _selectedPanel = 1);
        }
      } else if (_selectedPanel == 1) {
        if (_seasonIdx < _seasons.length - 1) {
          setState(() => _seasonIdx++);
          _loadEpisodes(_seasons[_seasonIdx]);
          _scrollTo(_seasonScroll, _seasonIdx);
        } else {
          setState(() => _selectedPanel = 2);
        }
      } else if (_selectedPanel == 2) {
        if (_episodeIdx < _episodes.length - 1) {
          setState(() => _episodeIdx++);
          _scrollEpisodeTo(_episodeIdx);
        }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_isBackFocused) {
        Get.back();
      } else if (_selectedPanel == 1) {
        _loadEpisodes(_seasons[_seasonIdx]);
      } else if (_selectedPanel == 2) {
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

  void _playEpisode() {
    if (_episodes.isEmpty || _episodeIdx >= _episodes.length) return;

    final model = _episodes[_episodeIdx];
    final userAuth = context.read<AuthBloc>().state;
    if (userAuth is! AuthSuccess) return;

    final link =
        "${userAuth.user.serverInfo!.serverUrl}/series/${userAuth.user.userInfo!.username}/${userAuth.user.userInfo!.password}/${model!.id}.${model.containerExtension}";

    debugPrint("Link: $link");
    Get.to(() => FullVideoScreen(link: link, title: model.title ?? ""))!.then((
      slider,
    ) {
      debugPrint("DATA: $slider");
      if (slider != null) {
        var watchModel = WatchingModel(
          sliderValue: slider[0],
          durationStrm: slider[1],
          stream: link,
          title: model.title ?? "",
          image: model.info!.movieImage ?? _serieDetails.info!.cover ?? "",
          streamId: model.id.toString(),
        );
        context.read<WatchingCubit>().addSerie(watchModel);
      }
    });
  }

  void _scrollTo(ScrollController sc, int idx) {
    if (!sc.hasClients) return;
    const itemH = 50.0;
    final target = (idx * itemH).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _scrollEpisodeTo(int idx) {
    if (!_episodeScroll.hasClients) return;
    const itemW = 160.0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _navFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthSuccess) {
              return Stack(
                children: [
                  CardMovieImagesBackground(
                    listImages: _serieDetails.info!.backdropPath ?? [],
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
                        stops: [0.0, 0.25, 0.6, 1.0],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 10),
                        _buildSerieInfo(),
                        const SizedBox(height: 20),
                        _buildSeasonsList(),
                        const SizedBox(height: 15),
                        _buildEpisodesList(),
                      ],
                    ),
                  ),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isBackFocused ? kColorPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                FontAwesomeIcons.chevronLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "SEASONS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerieInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: _serieDetails.info!.cover ?? "",
              width: 60,
              height: 80,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 60,
                height: 80,
                color: kColorCardLight,
                child: const Icon(
                  FontAwesomeIcons.tv,
                  color: kColorHint,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _serieDetails.info!.name ?? "",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonsList() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        controller: _seasonScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _seasons.length,
        itemBuilder: (context, idx) {
          final isSelected = idx == _seasonIdx && _selectedPanel == 1;
          return GestureDetector(
            onTap: () {
              setState(() {
                _seasonIdx = idx;
                _selectedPanel = 1;
              });
              _loadEpisodes(_seasons[idx]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [kColorPrimary, kColorPrimaryDark],
                      )
                    : LinearGradient(
                        colors: [
                          kColorPrimary.withValues(alpha: 0.3),
                          kColorPrimaryDark.withValues(alpha: 0.3),
                        ],
                      ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? kColorFocus : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                "Season ${_seasons[idx]}",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodesList() {
    if (_episodes.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            "No episodes available",
            style: TextStyle(color: kColorHint),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Episodes",
              style: TextStyle(
                color: kColorHint,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              controller: _episodeScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _episodes.length,
              itemBuilder: (context, idx) {
                final ep = _episodes[idx];
                final isSelected = idx == _episodeIdx;
                final isFocused = idx == _episodeIdx && _selectedPanel == 2;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _episodeIdx = idx;
                      _selectedPanel = 2;
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
                                _serieDetails.info!.cover ??
                                "",
                            width: 150,
                            height: 100,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 150,
                              height: 100,
                              color: kColorCardDark,
                              child: const Icon(
                                FontAwesomeIcons.tv,
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
                        if (isFocused)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: kColorFocus,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                FontAwesomeIcons.play,
                                color: Colors.white,
                                size: 10,
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
      ),
    );
  }
}
