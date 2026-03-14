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
  bool _isBackFocused = false;
  bool _hasTrailer = false;

  @override
  void initState() {
    super.initState();
    _future = IpTvApi.getSerieDetails(widget.videoId);
  }

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

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
      if (_isBackFocused) {
        return KeyEventResult.handled;
      }
      if (_selectedButton > 0) {
        setState(() => _selectedButton--);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_isBackFocused) {
        return KeyEventResult.handled;
      }
      final maxButton = _hasTrailer ? 2 : 1;
      if (_selectedButton < maxButton) {
        setState(() => _selectedButton++);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_isBackFocused) {
        Get.back();
      } else {
        _onButtonPressed();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onButtonPressed() {}

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

                      if (!_hasTrailer) {
                        _hasTrailer =
                            serie.info!.youtubeTrailer != null &&
                            serie.info!.youtubeTrailer!.isNotEmpty;
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
                                  onPressed: () => Get.back(),
                                  icon: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isBackFocused
                                          ? kColorPrimary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      FontAwesomeIcons.chevronLeft,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              _buildButtons(serie),
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

  Widget _buildButtons(SerieDetails serie) {
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
                onTap: () {
                  Get.to(() => SerieSeasons(serieDetails: serie));
                },
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
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (builder) => DialogTrailerYoutube(
                        thumb:
                            serie.info!.backdropPath != null &&
                                serie.info!.backdropPath!.isNotEmpty
                            ? serie.info!.backdropPath!.first
                            : null,
                        trailer: serie.info!.youtubeTrailer ?? "",
                      ),
                    );
                  },
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
                      boxShadow: _selectedButton == 1
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
                          FontAwesomeIcons.youtube,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
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
              onTap: () {
                context.read<FavoritesCubit>().addSerie(
                  widget.channelSerie,
                  isAdd: !isLiked,
                );
              },
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
}
