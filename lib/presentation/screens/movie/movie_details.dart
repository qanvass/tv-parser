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
  MovieDetail? _movieDetail;
  final _navFocus = FocusNode();

  int _selectedButton = -1;
  bool _isBackFocused = false;
  bool _hasTrailer = false;

  @override
  void initState() {
    super.initState();
    _future = IpTvApi.getMovieDetails(widget.videoId);
    _future.then((detail) {
      if (mounted && detail != null) {
        setState(() {
          _movieDetail = detail;
          _hasTrailer =
              detail.info?.youtubeTrailer != null &&
              detail.info!.youtubeTrailer!.isNotEmpty;
          _selectedButton = 0; // default focus on PLAY
        });
      }
    });
  }

  void _reload() {
    setState(() {
      _movieDetail = null;
      _selectedButton = -1;
      _isBackFocused = false;
      _future = IpTvApi.getMovieDetails(widget.videoId);
      _future.then((detail) {
        if (mounted && detail != null) {
          setState(() {
            _movieDetail = detail;
            _hasTrailer =
                detail.info?.youtubeTrailer != null &&
                detail.info!.youtubeTrailer!.isNotEmpty;
            _selectedButton = 0;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  // Layout:
  //  Left column  |  Right content
  //  [Back]       |  [PLAY]
  //  [Spacer]     |
  //  [Trailer?]   |
  //  [Fav]        |
  //
  // Up/Down → navigate within left column
  // Left     → PLAY → left column
  // Right    → left column → PLAY
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final favIdx = _hasTrailer ? 2 : 1;

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_isBackFocused) return KeyEventResult.handled;
      if (_selectedButton == 0) {
        // PLAY → Back
        setState(() { _isBackFocused = true; _selectedButton = -1; });
      } else if (_selectedButton == favIdx && _hasTrailer) {
        // Fav → Trailer
        setState(() => _selectedButton = 1);
      } else {
        // Trailer or Fav (no trailer) → Back
        setState(() { _isBackFocused = true; _selectedButton = -1; });
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      if (_isBackFocused) {
        // Back → Trailer (if exists) else Fav
        setState(() { _isBackFocused = false; _selectedButton = 1; });
      } else if (_selectedButton == 1 && _hasTrailer) {
        // Trailer → Fav
        setState(() => _selectedButton = 2);
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_selectedButton == 0) {
        // PLAY → left column (Trailer if available, else Fav)
        setState(() => _selectedButton = 1);
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowRight) {
      if (_isBackFocused || _selectedButton > 0) {
        // Any left column item → PLAY
        setState(() { _isBackFocused = false; _selectedButton = 0; });
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
    if (_movieDetail == null) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;
    final userAuth = authState.user;

    if (_selectedButton == 0) {
      // Play
      final watchingCubit = context.read<WatchingCubit>();
      final link =
          "${userAuth.serverInfo!.serverUrl}/movie/${userAuth.userInfo!.username}/${userAuth.userInfo!.password}/${_movieDetail!.movieData!.streamId}.${_movieDetail!.movieData!.containerExtension}";
      Get.to(
        () => FullVideoScreen(
          link: link,
          title: _movieDetail!.movieData!.name ?? "",
        ),
      )?.then((slider) {
        if (slider != null) {
          final model = WatchingModel(
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
    } else if (_selectedButton == 1 && _hasTrailer) {
      // Trailer
      showDialog(
        context: context,
        builder: (_) => DialogTrailerYoutube(
          thumb:
              _movieDetail!.info!.backdropPath != null &&
                  _movieDetail!.info!.backdropPath!.isNotEmpty
              ? _movieDetail!.info!.backdropPath!.first
              : null,
          trailer: _movieDetail!.info!.youtubeTrailer ?? "",
        ),
      );
    } else {
      // Favorite
      final favState = context.read<FavoritesCubit>().state;
      final isLiked = favState.movies.any(
        (m) => m.streamId == widget.channelMovie.streamId,
      );
      context.read<FavoritesCubit>().addMovie(
        widget.channelMovie,
        isAdd: !isLiked,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _navFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: FutureBuilder<MovieDetail?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _DetailsLoadingState(title: widget.channelMovie.name ?? '');
            }
            if (!snapshot.hasData) {
              return _DetailsErrorState(
                onBack: Get.back,
                onReload: _reload,
              );
            }

            final movie = snapshot.data!;

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
                  padding: const EdgeInsets.only(top: 25, left: 20, right: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30, left: 0),
                        child: Column(
                          spacing: 5,
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
                                    color: _isBackFocused
                                        ? kColorFocus
                                        : Colors.transparent,
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
                            if (movie.info!.youtubeTrailer != null &&
                                movie.info!.youtubeTrailer!.isNotEmpty) ...[
                              _FocusableButton(
                                icon: FontAwesomeIcons.youtube,
                                isSelected: _selectedButton == 1,
                                onTap: () {
                                  setState(() => _selectedButton = 1);
                                  _onButtonPressed();
                                },
                              ),
                              const SizedBox(width: 10),
                            ],
                            BlocBuilder<FavoritesCubit, FavoritesState>(
                              builder: (context, favState) {
                                final isLiked = favState.movies.any(
                                  (m) =>
                                      m.streamId ==
                                      widget.channelMovie.streamId,
                                );
                                return _FocusableButton(
                                  icon: isLiked
                                      ? FontAwesomeIcons.solidHeart
                                      : FontAwesomeIcons.heart,
                                  isSelected:
                                      _selectedButton == (_hasTrailer ? 2 : 1),
                                  isFavorite: true,
                                  onTap: () {
                                    setState(
                                      () =>
                                          _selectedButton = _hasTrailer ? 2 : 1,
                                    );
                                    _onButtonPressed();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      //TODO add here
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                movie.info!.movieImage ?? "",
                                            width: 140,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                  width: 140,
                                                  height: 200,
                                                  color: kColorCardLight,
                                                  child: const Icon(
                                                    FontAwesomeIcons.film,
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
                                                movie.movieData!.name ?? "",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons
                                                    .clapperboard,
                                                label: 'Director',
                                                value:
                                                    movie.info!.director ?? "",
                                              ),
                                              const SizedBox(height: 10),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons
                                                    .calendarDay,
                                                label: 'Release',
                                                value: expirationDate(
                                                  movie.info!.releasedate,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons.clock,
                                                label: 'Duration',
                                                value:
                                                    movie.info!.duration ?? "",
                                              ),
                                              const SizedBox(height: 10),
                                              _buildInfoRow(
                                                icon: FontAwesomeIcons.film,
                                                label: 'Genre',
                                                value: movie.info!.genre ?? "",
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: 130,
                                                child: _FocusableButton(
                                                  label: "PLAY",
                                                  icon: FontAwesomeIcons.play,
                                                  isSelected:
                                                      _selectedButton == 0,
                                                  onTap: () {
                                                    setState(
                                                      () => _selectedButton = 0,
                                                    );
                                                    _onButtonPressed();
                                                  },
                                                ),
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
}

class _FocusableButton extends StatelessWidget {
  const _FocusableButton({
    this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isFavorite = false,
  });

  final String? label;
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
          spacing: 6,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            if (label != null)
              Text(
                label!,
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
