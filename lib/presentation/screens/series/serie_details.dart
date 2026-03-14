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
  final _navFocus = FocusNode();

  int _selectedButton = 0;
  int _selectedPanel = 0;
  int _seasonIdx = 0;
  int _episodeIdx = 0;

  bool _isBackFocused = false;
  bool _hasTrailer = false;
  bool _showSeasons = false;

  List<String> _seasons = [];
  List<Episode> _episodes = [];
  SerieDetails? _serieDetails;

  final _seasonScroll = ScrollController();
  final _episodeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = IpTvApi.getSerieDetails(widget.videoId);
  }

  @override
  void dispose() {
    _navFocus.dispose();
    _seasonScroll.dispose();
    _episodeScroll.dispose();
    super.dispose();
  }

  void _initSeasonsEpisodes(SerieDetails serie) {
    if (_seasons.isNotEmpty) return;
    if (serie.episodes != null && serie.episodes!.isNotEmpty) {
      _seasons = serie.episodes!.keys.toList();
      if (_seasons.isNotEmpty) {
        _loadEpisodes(_seasons[0]);
      }
    }
  }

  void _loadEpisodes(String season) {
    if (_serieDetails == null) return;
    final eps = _serieDetails!.episodes![season] ?? [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _episodes = eps.whereType<Episode>().toList();
          _episodeIdx = 0;
        });
        if (_episodeScroll.hasClients) {
          _episodeScroll.jumpTo(0);
        }
      }
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (_showSeasons) {
      return _onKeySeasons(e, k);
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (!_isBackFocused) {
        setState(() => _isBackFocused = true);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      if (_isBackFocused) {
        setState(() {
          _isBackFocused = false;
          _selectedButton = 0;
        });
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_isBackFocused) return KeyEventResult.handled;
      if (_selectedButton > 0) setState(() => _selectedButton--);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_isBackFocused) return KeyEventResult.handled;
      final maxButton = _hasTrailer ? 2 : 1;
      if (_selectedButton < maxButton) setState(() => _selectedButton++);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_isBackFocused) {
        Get.back();
      } else {
        _handleButtonPress();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (_showSeasons) {
        setState(() => _showSeasons = false);
      } else {
        Get.back();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onKeySeasons(KeyEvent e, LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowUp) {
      if (_selectedPanel == 0) {
        if (!_isBackFocused) {
          setState(() => _isBackFocused = true);
        }
      } else if (_selectedPanel == 1) {
        if (_seasonIdx > 0) {
          setState(() {
            _seasonIdx--;
            _loadEpisodes(_seasons[_seasonIdx]);
          });
          _scrollTo(_seasonScroll, _seasonIdx);
        } else {
          setState(() => _selectedPanel = 0);
        }
      } else if (_selectedPanel == 2) {
        if (_episodeIdx >= 5) {
          setState(() => _episodeIdx -= 5);
          _scrollEpisodeTo(_episodeIdx);
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
        setState(() => _selectedPanel = 1);
      } else if (_selectedPanel == 1) {
        if (_seasonIdx < _seasons.length - 1) {
          setState(() {
            _seasonIdx++;
            _loadEpisodes(_seasons[_seasonIdx]);
          });
          _scrollTo(_seasonScroll, _seasonIdx);
        } else {
          setState(() => _selectedPanel = 2);
        }
      } else if (_selectedPanel == 2) {
        if (_episodeIdx + 5 < _episodes.length) {
          setState(() => _episodeIdx += 5);
          _scrollEpisodeTo(_episodeIdx);
        }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_selectedPanel == 1) {
        if (_seasonIdx > 0) {
          setState(() {
            _seasonIdx--;
            _loadEpisodes(_seasons[_seasonIdx]);
          });
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
        setState(() => _selectedPanel = 1);
      } else if (_selectedPanel == 1) {
        if (_seasonIdx < _seasons.length - 1) {
          setState(() {
            _seasonIdx++;
            _loadEpisodes(_seasons[_seasonIdx]);
          });
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
        setState(() => _showSeasons = false);
      } else if (_selectedPanel == 1) {
        _loadEpisodes(_seasons[_seasonIdx]);
      } else if (_selectedPanel == 2) {
        _playEpisode();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.escape) {
      setState(() => _showSeasons = false);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleButtonPress() {
    if (_selectedButton == 0) {
      if (_seasons.isNotEmpty) {
        setState(() {
          _showSeasons = true;
          _selectedPanel = 1;
          _seasonIdx = 0;
        });
        _loadEpisodes(_seasons[0]);
      }
    }
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
      if (slider != null) {
        var watchModel = WatchingModel(
          sliderValue: slider[0],
          durationStrm: slider[1],
          stream: link,
          title: model.title ?? "",
          image: model.info!.movieImage ?? _serieDetails?.info?.cover ?? "",
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
          style: TextStyle(
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
                  FutureBuilder<SerieDetails?>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          decoration: kDecorBackground,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: kColorPrimary,
                            ),
                          ),
                        );
                      } else if (!snapshot.hasData) {
                        return Container(
                          decoration: kDecorBackground,
                          child: const Center(
                            child: Text(
                              "Could not load data",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }

                      final serie = snapshot.data!;
                      _serieDetails = serie;

                      if (!_hasTrailer) {
                        _hasTrailer =
                            serie.info!.youtubeTrailer != null &&
                            serie.info!.youtubeTrailer!.isNotEmpty;
                      }
                      if (_seasons.isEmpty && serie.episodes != null) {
                        _initSeasonsEpisodes(serie);
                      }

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
                            padding: const EdgeInsets.only(
                              top: 25,
                              left: 10,
                              right: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  focusColor: kColorFocus,
                                  onPressed: () => _showSeasons
                                      ? setState(() => _showSeasons = false)
                                      : Get.back(),
                                  icon: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isBackFocused && !_showSeasons
                                          ? kColorPrimary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      FontAwesomeIcons.chevronLeft,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 10),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          serie.info!.cover ??
                                                          "",
                                                      width: 140,
                                                      height: 200,
                                                      fit: BoxFit.cover,
                                                      errorWidget:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => Container(
                                                            width: 140,
                                                            height: 200,
                                                            color:
                                                                kColorCardLight,
                                                            child: const Icon(
                                                              FontAwesomeIcons
                                                                  .tv,
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
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          serie.info!.name ??
                                                              "",
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 22,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        _buildInfoRow(
                                                          icon: FontAwesomeIcons
                                                              .clapperboard,
                                                          label: 'Director',
                                                          value:
                                                              serie
                                                                  .info!
                                                                  .director ??
                                                              "",
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        _buildInfoRow(
                                                          icon: FontAwesomeIcons
                                                              .calendarDay,
                                                          label: 'Release',
                                                          value:
                                                              serie
                                                                  .info!
                                                                  .releaseDate ??
                                                              "",
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        _buildInfoRow(
                                                          icon: FontAwesomeIcons
                                                              .film,
                                                          label: 'Genre',
                                                          value:
                                                              serie
                                                                  .info!
                                                                  .genre ??
                                                              "",
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                'Plot',
                                                style: TextStyle(
                                                  color: kColorHint,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                serie.info!.plot ?? "",
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              _buildButtons(),
                                              const SizedBox(height: 20),
                                              if (_showSeasons)
                                                _buildSeasonsEpisodes(),
                                              const SizedBox(height: 40),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

  Widget _buildButtons() {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favState) {
        final isLiked = favState.series
            .where((s) => s.seriesId == widget.channelSerie.seriesId)
            .isNotEmpty;
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _handleButtonPress,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: _selectedButton == 0
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
                      color: _selectedButton == 0
                          ? kColorFocus
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: _selectedButton == 0
                        ? [
                            BoxShadow(
                              color: kColorFocus.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        FontAwesomeIcons.list,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "SEASONS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (_hasTrailer)
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {},
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: _selectedButton == 1
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
                        color: _selectedButton == 1
                            ? kColorFocus
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.youtube,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "TRAILER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_hasTrailer) const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.read<FavoritesCubit>().addSerie(
                widget.channelSerie,
                isAdd: !isLiked,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  gradient:
                      (_hasTrailer
                          ? _selectedButton == 2
                          : _selectedButton == 1)
                      ? const LinearGradient(
                          colors: [kColorPrimary, kColorPrimaryDark],
                        )
                      : LinearGradient(
                          colors: [
                            Colors.red.withValues(alpha: 0.3),
                            Colors.red.withValues(alpha: 0.3),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (_hasTrailer
                            ? _selectedButton == 2
                            : _selectedButton == 1)
                        ? kColorFocus
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLiked
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.heart,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "FAV",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeasonsEpisodes() {
    if (_seasons.isEmpty) {
      return const Center(
        child: Text(
          "No seasons available",
          style: TextStyle(color: kColorHint),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            controller: _seasonScroll,
            scrollDirection: Axis.horizontal,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Episodes",
          style: TextStyle(
            color: kColorHint,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _episodeScroll,
            scrollDirection: Axis.horizontal,
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
                              _serieDetails?.info?.cover ??
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
