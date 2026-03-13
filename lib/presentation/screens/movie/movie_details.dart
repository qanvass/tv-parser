part of '../screens.dart';

class MovieContent extends StatefulWidget {
  const MovieContent({
    super.key,
    required this.videoId,
    required this.channelMovie,
  });

  final String videoId;
  final ChannelMovie channelMovie;

  @override
  State<MovieContent> createState() => _MovieContentState();
}

class _MovieContentState extends State<MovieContent> {
  late Future<MovieDetail?> _future;
  final _navFocus = FocusNode();
  bool _showControls = true;
  bool _isFullscreen = false;

  int _selectedButton = 0;
  bool _isBackFocused = false;
  bool _hasTrailer = false;

  @override
  void initState() {
    super.initState();
    _future = IpTvApi.getMovieDetails(widget.videoId);
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

  void _onButtonPressed() {
    // _selectedButton: 0 = Play, 1 = Trailer (if available), 2 = Fav
    // Back is handled separately via _isBackFocused
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
              final userAuth = state.user;
              return Stack(
                children: [
                  FutureBuilder<MovieDetail?>(
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

                      final movie = snapshot.data!;

                      if (!_hasTrailer) {
                        _hasTrailer =
                            movie.info!.youtubeTrailer != null &&
                            movie.info!.youtubeTrailer!.isNotEmpty;
                      }

                      return Stack(
                        children: [
                          CardMovieImagesBackground(
                            listImages:
                                movie.info!.backdropPath ??
                                [movie.info!.movieImage ?? ""],
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
                              //mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  focusColor: kColorFocus,
                                  onPressed: () => Get.back(),
                                  icon: const Icon(
                                    FontAwesomeIcons.chevronLeft,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // _buildHeader(),
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
                                                          movie
                                                              .info!
                                                              .movieImage ??
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
                                                                  .film,
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
                                                          movie
                                                                  .movieData!
                                                                  .name ??
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
                                                              movie
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
                                                          value: expirationDate(
                                                            movie
                                                                .info!
                                                                .releasedate,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        _buildInfoRow(
                                                          icon: FontAwesomeIcons
                                                              .clock,
                                                          label: 'Duration',
                                                          value:
                                                              movie
                                                                  .info!
                                                                  .duration ??
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
                                                              movie
                                                                  .info!
                                                                  .genre ??
                                                              "",
                                                        ),

                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        _buildButtons(
                                                          movie,
                                                          userAuth,
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
                                                movie.info!.plot ?? "",
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                  height: 1.5,
                                                ),
                                              ),
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
                color: _isBackFocused
                    ? kColorPrimary
                    : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBackFocused ? kColorFocus : Colors.transparent,
                  width: 2,
                ),
              ),
              child: const Icon(
                FontAwesomeIcons.chevronLeft,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
        ],
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

  Widget _buildButtons(MovieDetail movie, UserModel userAuth) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favState) {
        final isLiked = favState.movies
            .where((m) => m.streamId == widget.channelMovie.streamId)
            .isNotEmpty;
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _FocusableButton(
                label: "PLAY",
                icon: FontAwesomeIcons.play,
                isSelected: _selectedButton == 0,
                onTap: () {
                  final watchingCubit = context.read<WatchingCubit>();
                  final link =
                      "${userAuth.serverInfo!.serverUrl}/movie/${userAuth.userInfo!.username}/${userAuth.userInfo!.password}/${movie.movieData!.streamId}.${movie.movieData!.containerExtension}";

                  debugPrint("URL: $link");
                  Get.to(
                    () => FullVideoScreen(
                      link: link,
                      title: movie.movieData!.name ?? "",
                    ),
                  )!.then((slider) {
                    debugPrint("DATA: $slider");
                    if (slider != null) {
                      var model = WatchingModel(
                        sliderValue: slider[0],
                        durationStrm: slider[1],
                        stream: link,
                        title: widget.channelMovie.name ?? "",
                        image: widget.channelMovie.streamIcon ?? "",
                        streamId: widget.channelMovie.streamId.toString(),
                      );
                      watchingCubit.addMovie(model);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            if (movie.info!.youtubeTrailer != null &&
                movie.info!.youtubeTrailer!.isNotEmpty)
              Expanded(
                flex: 2,
                child: _FocusableButton(
                  label: "TRAILER",
                  icon: FontAwesomeIcons.youtube,
                  isSelected: _selectedButton == 1,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (builder) => DialogTrailerYoutube(
                        thumb:
                            movie.info!.backdropPath != null &&
                                movie.info!.backdropPath!.isNotEmpty
                            ? movie.info!.backdropPath!.first
                            : null,
                        trailer: movie.info!.youtubeTrailer ?? "",
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(width: 10),
            _FocusableButton(
              label: isLiked ? "FAV" : "FAV",
              icon: isLiked
                  ? FontAwesomeIcons.solidHeart
                  : FontAwesomeIcons.heart,
              isSelected: _selectedButton == (_hasTrailer ? 2 : 1),
              isFavorite: true,
              onTap: () {
                context.read<FavoritesCubit>().addMovie(
                  widget.channelMovie,
                  isAdd: !isLiked,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _FocusableButton extends StatelessWidget {
  const _FocusableButton({
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
        padding: EdgeInsets.symmetric(
          vertical: isFavorite ? 10 : 10,
          horizontal: isFavorite ? 12 : 14,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [kColorPrimary, kColorPrimaryDark])
              : isFavorite
              ? LinearGradient(
                  colors: [
                    Colors.red.withValues(alpha: 0.3),
                    Colors.red.withValues(alpha: 0.3),
                  ],
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
