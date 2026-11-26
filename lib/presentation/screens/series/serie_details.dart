part of '../screens.dart';

/// Series details: cinematic header, season pills and episode cards.
///
/// One focus node drives the whole page with the remote. Focus zones, top to
/// bottom: Back, header actions, seasons, episodes.
class SerieContent extends StatefulWidget {
  const SerieContent({
    super.key,
    required this.videoId,
    required this.channelSerie,
    this.autoPlay = false,
    this.autoSeason,
    this.autoEpisode,
  });

  final String videoId;
  final ChannelSerie channelSerie;

  /// Set only by a remote "play by name" request: start an episode as soon as
  /// the page has its list (the one asked for, else the one watched last,
  /// else the first).
  final bool autoPlay;
  final int? autoSeason;
  final int? autoEpisode;

  @override
  State<SerieContent> createState() => _SerieContentState();
}

enum _SerieZone { back, actions, seasons, episodes }

enum _SerieAction { play, myList, trailer }

class _SerieContentState extends State<SerieContent> {
  late Future<SerieDetails?> _future;
  SerieDetails? _serieDetails;
  bool _loadFailed = false;
  final _navFocus = FocusNode();
  final _backGate = TvBackGate();

  _SerieZone _zone = _SerieZone.actions;
  int _actionIdx = 0;
  int _seasonIdx = 0;
  int _episodeIdx = 0;
  bool _hasTrailer = false;

  List<String> _seasons = [];
  List<Episode> _episodes = [];

  /// Verified artwork for the show, and episode stills per season key.
  /// Both stay empty when there is no confident match.
  SeriesShowArt? _showArt;
  final Map<String, Map<int, SeriesEpisodeArt>> _seasonArt = {};
  Timer? _seasonArtTimer;
  int _loadGen = 0;

  final _pageScroll = ScrollController();
  final _seasonScroll = ScrollController();
  final _episodeScroll = ScrollController();

  // Item extents of the two rails, set by build so D-pad scrolling is exact.
  double _seasonExtent = 128;
  double _episodeExtent = 162;

  List<_SerieAction> get _actions => [
    _SerieAction.play,
    _SerieAction.myList,
    if (_hasTrailer) _SerieAction.trailer,
  ];

  void _popDetails({String source = 'focus'}) {
    if (!mounted) return;
    if (!_backGate.allow(screen: 'SerieContent', source: source)) return;
    if (!Navigator.of(context).canPop()) return;
    _backGate.markRouteExit();
    logTvBack(
      screen: 'SerieContent',
      source: source,
      action: 'popRoute',
      blockedDuplicate: false,
      routeBefore: Get.currentRoute,
    );
    Get.back();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final gen = ++_loadGen;
    _future = IpTvApi.getSerieDetails(
      widget.videoId,
      saved: widget.channelSerie,
    );
    _future.then((serie) {
      if (!mounted || gen != _loadGen) return;
      if (serie == null) {
        setState(() => _loadFailed = true);
        if (widget.autoPlay && !_autoPlayed) {
          _autoPlayed = true;
          PlaybackReport.noEpisode('its episode list did not load');
        }
        return;
      }
      final trailer = serie.info?.youtubeTrailer;
      setState(() {
        _serieDetails = serie;
        _hasTrailer = trailer != null && trailer.isNotEmpty;
        _zone = _SerieZone.actions;
        _actionIdx = 0;
      });
      _initSeasonsEpisodes(serie);
      _loadShowArt(serie, gen);
      if (widget.autoPlay) _autoPlayOnce();
    });
  }

  bool _autoPlayed = false;

  /// Remote "play by name": picks the episode and presses Play once.
  void _autoPlayOnce() {
    if (_autoPlayed) return;
    _autoPlayed = true;
    if (_seasons.isEmpty) {
      PlaybackReport.noEpisode('it has no episodes listed');
      return;
    }
    final wantSeason = widget.autoSeason;
    final wantEpisode = widget.autoEpisode;
    if (wantSeason == null && wantEpisode == null) {
      _playPrimary();
    } else {
      final seasonIdx = wantSeason == null
          ? 0
          : RemoteWatchService.numberedIndex(_seasons, wantSeason);
      if (seasonIdx < 0) {
        PlaybackReport.noEpisode(
          'it has no season $wantSeason (seasons listed: ${_seasons.length})',
        );
        return;
      }
      final eps = _episodesOf(_seasons[seasonIdx]);
      final episodeIdx = wantEpisode == null
          ? 0
          : RemoteWatchService.numberedIndex(
              [for (final e in eps) e.episodeNum ?? ''],
              wantEpisode,
              byPosition: true,
            );
      if (eps.isEmpty || episodeIdx < 0) {
        PlaybackReport.noEpisode(
          'season ${wantSeason ?? 1} has no episode ${wantEpisode ?? 1} '
          '(episodes listed: ${eps.length})',
        );
        return;
      }
      setState(() => _seasonIdx = seasonIdx);
      _loadEpisodes(_seasons[seasonIdx], episodeIdx: episodeIdx);
      _scrollSeasonTo(seasonIdx);
      _playEpisode();
    }
    if (_episodes.isEmpty || _episodeIdx >= _episodes.length) return;
    final seasonNo =
        RemoteWatchService.firstNumber(_seasons[_seasonIdx]) ?? _seasonIdx + 1;
    final episodeNo =
        RemoteWatchService.firstNumber(_episodes[_episodeIdx].episodeNum ?? '') ??
        _episodeIdx + 1;
    PlaybackReport.note = '$_seriesTitle, season $seasonNo episode $episodeNo';
  }

  void _reload() {
    _seasonArtTimer?.cancel();
    setState(() {
      _serieDetails = null;
      _loadFailed = false;
      _hasTrailer = false;
      _seasons = [];
      _episodes = [];
      _seasonIdx = 0;
      _episodeIdx = 0;
      _zone = _SerieZone.actions;
      _actionIdx = 0;
      _showArt = null;
      _seasonArt.clear();
      _load();
    });
  }

  @override
  void dispose() {
    _loadGen++;
    _seasonArtTimer?.cancel();
    _navFocus.dispose();
    _pageScroll.dispose();
    _seasonScroll.dispose();
    _episodeScroll.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  void _initSeasonsEpisodes(SerieDetails serie) {
    if (_seasons.isNotEmpty) return;
    final map = serie.episodes;
    if (map == null || map.isEmpty) return;
    _seasons = map.keys.toList();
    // Open on the episode the viewer watched last, when there is one.
    final resume = _resumePoint(context.read<WatchingCubit>().state);
    if (resume != null) {
      _seasonIdx = resume.seasonIdx;
      _loadEpisodes(_seasons[_seasonIdx], episodeIdx: resume.episodeIdx);
    } else {
      _loadEpisodes(_seasons[0]);
    }
  }

  List<Episode> _episodesOf(String season) =>
      (_serieDetails?.episodes?[season] ?? const <Episode?>[])
          .whereType<Episode>()
          .toList();

  void _loadEpisodes(String season, {int episodeIdx = 0}) {
    if (_serieDetails == null) return;
    final eps = _episodesOf(season);
    setState(() {
      _episodes = eps;
      _episodeIdx = eps.isEmpty ? 0 : episodeIdx.clamp(0, eps.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollEpisodeTo(_episodeIdx, animate: false);
    });
    _scheduleSeasonArt(season);
  }

  /// Most recently watched episode of this show, from the watch history.
  ({int seasonIdx, int episodeIdx, WatchingModel watch})? _resumePoint(
    WatchingState watch,
  ) {
    if (_serieDetails == null || watch.series.isEmpty || _seasons.isEmpty) {
      return null;
    }
    final where = <String, (int, int)>{};
    for (var s = 0; s < _seasons.length; s++) {
      final eps = _episodesOf(_seasons[s]);
      for (var e = 0; e < eps.length; e++) {
        final id = eps[e].id;
        if (id != null && id.isNotEmpty && id != 'null') where[id] = (s, e);
      }
    }
    for (final w in watch.series) {
      final hit = where[w.streamId];
      if (hit != null) return (seasonIdx: hit.$1, episodeIdx: hit.$2, watch: w);
    }
    return null;
  }

  static WatchingModel? _watchOf(WatchingState watch, Episode ep) {
    final id = ep.id;
    if (id == null || id.isEmpty) return null;
    for (final w in watch.series) {
      if (w.streamId == id) return w;
    }
    return null;
  }

  String get _seriesTitle =>
      _usable(_serieDetails?.info?.name) ??
      _usable(widget.channelSerie.name) ??
      '';

  static String? _usable(String? v) {
    final s = v?.trim() ?? '';
    return s.isEmpty || s == 'null' ? null : s;
  }

  static String? _usableImage(String? v) =>
      ArtworkUrlResolver.isUsableImageUrl(v) ? v!.trim() : null;

  int? get _providerYear {
    final fromName = TitleNormalizer.parse(widget.channelSerie.name ?? '').year;
    if (fromName != null) return fromName;
    final date = _usable(_serieDetails?.info?.releaseDate);
    if (date == null || date.length < 4) return null;
    final y = int.tryParse(date.substring(0, 4));
    return y != null && y > 1900 && y < 2100 ? y : null;
  }

  /// Looks up verified artwork beside the page; the page never waits for it.
  Future<void> _loadShowArt(SerieDetails serie, int gen) async {
    final title = _seriesTitle;
    if (title.isEmpty) return;
    final art = await SeriesArtworkService.instance.show(
      title: title,
      year: _providerYear,
      providerTmdbId: serie.info?.tmdbId,
    );
    if (!mounted || gen != _loadGen || art == null) return;
    setState(() => _showArt = art);
    if (_seasons.isNotEmpty) _scheduleSeasonArt(_seasons[_seasonIdx]);
  }

  /// Fetches episode stills once the season choice settles, so holding
  /// Left/Right across seasons does not start a request per season.
  void _scheduleSeasonArt(String season) {
    _seasonArtTimer?.cancel();
    final art = _showArt;
    final number = int.tryParse(season);
    if (art == null || number == null || _seasonArt.containsKey(season)) return;
    final gen = _loadGen;
    _seasonArtTimer = Timer(const Duration(milliseconds: 280), () async {
      final eps = await SeriesArtworkService.instance.season(
        art.tmdbId,
        number,
      );
      if (!mounted || gen != _loadGen || eps.isEmpty) return;
      setState(() => _seasonArt[season] = eps);
    });
  }

  // ── Scrolling ─────────────────────────────────────────────────────────────

  void _scrollPage({required bool toTop}) {
    if (!_pageScroll.hasClients) return;
    _pageScroll.animateTo(
      toTop ? 0 : _pageScroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRail(
    ScrollController c,
    int idx,
    double extent, {
    bool animate = true,
  }) {
    if (!c.hasClients) return;
    // Keep one item visible before the focused one.
    final target = ((idx - 1) * extent).clamp(0.0, c.position.maxScrollExtent);
    if (animate) {
      c.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else {
      c.jumpTo(target);
    }
  }

  void _scrollSeasonTo(int idx) =>
      _scrollRail(_seasonScroll, idx, _seasonExtent);

  void _scrollEpisodeTo(int idx, {bool animate = true}) =>
      _scrollRail(_episodeScroll, idx, _episodeExtent, animate: animate);

  void _setZone(_SerieZone zone) {
    setState(() => _zone = zone);
    switch (zone) {
      case _SerieZone.back:
      case _SerieZone.actions:
        _scrollPage(toTop: true);
      case _SerieZone.seasons:
        _scrollPage(toTop: false);
        _scrollSeasonTo(_seasonIdx);
      case _SerieZone.episodes:
        _scrollPage(toTop: false);
        _scrollEpisodeTo(_episodeIdx);
    }
  }

  void _selectSeason(int idx) {
    if (idx < 0 || idx >= _seasons.length || idx == _seasonIdx) return;
    setState(() => _seasonIdx = idx);
    _loadEpisodes(_seasons[idx]);
    _scrollSeasonTo(idx);
  }

  // ── Remote ────────────────────────────────────────────────────────────────

  static bool _isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.gameButtonA;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;

    if (isTvBackKey(k)) {
      if (e is KeyDownEvent) _popDetails(source: 'focus');
      return KeyEventResult.handled;
    }

    // Loading or failed: only Back, and OK to try again after a failure.
    if (_serieDetails == null) {
      if (_loadFailed && e is KeyDownEvent && _isOk(k)) _reload();
      return KeyEventResult.handled;
    }

    final hasSeasons = _seasons.isNotEmpty;
    final hasEpisodes = _episodes.isNotEmpty;

    if (k == LogicalKeyboardKey.arrowUp) {
      switch (_zone) {
        case _SerieZone.back:
          break;
        case _SerieZone.actions:
          _setZone(_SerieZone.back);
        case _SerieZone.seasons:
          _setZone(_SerieZone.actions);
        case _SerieZone.episodes:
          _setZone(_SerieZone.seasons);
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      switch (_zone) {
        case _SerieZone.back:
          _setZone(_SerieZone.actions);
        case _SerieZone.actions:
          if (hasSeasons) _setZone(_SerieZone.seasons);
        case _SerieZone.seasons:
          if (hasEpisodes) _setZone(_SerieZone.episodes);
        case _SerieZone.episodes:
          break;
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      switch (_zone) {
        case _SerieZone.back:
          break;
        case _SerieZone.actions:
          if (_actionIdx > 0) setState(() => _actionIdx--);
        case _SerieZone.seasons:
          _selectSeason(_seasonIdx - 1);
        case _SerieZone.episodes:
          if (_episodeIdx > 0) {
            setState(() => _episodeIdx--);
            _scrollEpisodeTo(_episodeIdx);
          }
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowRight) {
      switch (_zone) {
        case _SerieZone.back:
          _setZone(_SerieZone.actions);
        case _SerieZone.actions:
          if (_actionIdx < _actions.length - 1) setState(() => _actionIdx++);
        case _SerieZone.seasons:
          _selectSeason(_seasonIdx + 1);
        case _SerieZone.episodes:
          if (_episodeIdx < _episodes.length - 1) {
            setState(() => _episodeIdx++);
            _scrollEpisodeTo(_episodeIdx);
          }
      }
      return KeyEventResult.handled;
    }

    if (e is! KeyDownEvent) return KeyEventResult.ignored;

    if (k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      if (_zone == _SerieZone.episodes) {
        _playEpisode();
      } else {
        _playPrimary();
      }
      return KeyEventResult.handled;
    }

    if (_isOk(k)) {
      switch (_zone) {
        case _SerieZone.back:
          _popDetails(source: 'focus');
        case _SerieZone.actions:
          _runAction(_actions[_actionIdx.clamp(0, _actions.length - 1)]);
        case _SerieZone.seasons:
          if (hasEpisodes) _setZone(_SerieZone.episodes);
        case _SerieZone.episodes:
          _playEpisode();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _runAction(_SerieAction action) {
    switch (action) {
      case _SerieAction.play:
        _playPrimary();
      case _SerieAction.myList:
        _toggleFavorite();
      case _SerieAction.trailer:
        _openTrailer();
    }
  }

  bool _isLiked(FavoritesState favState) {
    final currentId = widget.channelSerie.seriesId ?? widget.videoId;
    if (currentId.isNotEmpty) {
      return favState.series.any((s) => s.seriesId == currentId);
    }
    final currentName =
        (widget.channelSerie.name ?? _serieDetails?.info?.name ?? '')
            .trim()
            .toLowerCase();
    if (currentName.isNotEmpty) {
      return favState.series.any(
        (s) =>
            (s.seriesId == null || s.seriesId!.isEmpty) &&
            s.name != null &&
            s.name!.trim().toLowerCase() == currentName,
      );
    }
    return false;
  }

  void _openTrailer() {
    final info = _serieDetails?.info;
    if (!_hasTrailer || info == null) return;
    showDialog(
      context: context,
      builder: (_) => DialogTrailerYoutube(
        thumb: info.backdropPath != null && info.backdropPath!.isNotEmpty
            ? info.backdropPath!.first
            : null,
        trailer: info.youtubeTrailer ?? "",
        title: info.name ?? widget.channelSerie.name,
      ),
    );
  }

  void _toggleFavorite() {
    final cubit = context.read<FavoritesCubit>();
    final currentlyLiked = _isLiked(cubit.state);
    final info = _serieDetails?.info;

    final cover = widget.channelSerie.cover;
    final serieToSave = ChannelSerie(
      seriesId: widget.channelSerie.seriesId ?? widget.videoId,
      name: widget.channelSerie.name ?? info?.name,
      cover: (cover != null && cover.isNotEmpty) ? cover : info?.cover,
      plot: widget.channelSerie.plot ?? info?.plot,
      rating: widget.channelSerie.rating ?? info?.rating,
      rating5based: widget.channelSerie.rating5based ?? info?.rating5based,
      categoryId: widget.channelSerie.categoryId,
      directSource: widget.channelSerie.directSource,
      num: widget.channelSerie.num,
    );

    cubit.addSerie(serieToSave, isAdd: !currentlyLiked);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          currentlyLiked ? "Removed from Favourites" : "Added to Favourites",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: currentlyLiked
            ? Colors.grey.shade800
            : Colors.red.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Play button: the episode watched last, else the first episode.
  void _playPrimary() {
    if (_seasons.isEmpty) return;
    final resume = _resumePoint(context.read<WatchingCubit>().state);
    final seasonIdx = resume?.seasonIdx ?? 0;
    final episodeIdx = resume?.episodeIdx ?? 0;
    if (seasonIdx != _seasonIdx || episodeIdx != _episodeIdx) {
      setState(() => _seasonIdx = seasonIdx);
      _loadEpisodes(_seasons[seasonIdx], episodeIdx: episodeIdx);
      _scrollSeasonTo(seasonIdx);
    }
    _playEpisode();
  }

  void _playEpisode() {
    if (_episodes.isEmpty || _episodeIdx >= _episodes.length) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;
    final saved = _watchOf(
      context.read<WatchingCubit>().state,
      _episodes[_episodeIdx],
    );

    Get.to(
      () => SeriesPlayerScreen(
        episodes: _episodes,
        initialIdx: _episodeIdx,
        serverUrl: authState.user.serverInfo!.serverUrl ?? "",
        username: authState.user.userInfo!.username ?? "",
        password: authState.user.userInfo!.password ?? "",
        seriesCover: _serieDetails?.info?.cover ?? '',
        seriesTitle: _seriesTitle,
        startAt: saved == null
            ? null
            : Duration(seconds: saved.sliderValue.round()),
      ),
    );
  }

  // ── Presentation helpers ──────────────────────────────────────────────────

  String? _plotText(InfoSerie info) {
    final cleaned = MetadataEnrichmentService.cleanPlot(info.plot);
    if (cleaned != 'No description available for this title.' &&
        !cleaned.toLowerCase().contains('servicer')) {
      return cleaned;
    }
    return _usable(_showArt?.overview);
  }

  String? _ratingText(InfoSerie info) {
    final provider = double.tryParse(info.rating ?? '');
    final value = (provider != null && provider > 0)
        ? provider
        : _showArt?.rating;
    if (value == null || value <= 0 || value > 10) return null;
    return value.toStringAsFixed(1);
  }

  /// "Drama • Legal  |  2022 – Present  |  4 Seasons", from known facts only.
  List<String> _metaParts(InfoSerie info) {
    final parts = <String>[];
    final art = _showArt;
    final providerGenre = _usable(info.genre);
    if (providerGenre != null) {
      parts.add(
        providerGenre
            .split(RegExp(r'[,/|]'))
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .take(2)
            .join(' • '),
      );
    } else if (art != null && art.genres.isNotEmpty) {
      parts.add(art.genres.take(2).join(' • '));
    }
    final year = _providerYear ?? art?.year;
    if (year != null) {
      if (art?.inProduction == true) {
        parts.add('$year – Present');
      } else if (art?.endYear != null && art!.endYear! > year) {
        parts.add('$year – ${art.endYear}');
      } else {
        parts.add('$year');
      }
    }
    if (_seasons.isNotEmpty) {
      parts.add(
        _seasons.length == 1 ? '1 Season' : '${_seasons.length} Seasons',
      );
    }
    return parts;
  }

  static int _episodeNumber(Episode ep, int idx) =>
      int.tryParse(ep.episodeNum ?? '') ?? idx + 1;

  static String? _runtimeText(Episode ep, SeriesEpisodeArt? art) {
    final secs = int.tryParse(ep.info?.durationSecs ?? '');
    if (secs != null && secs > 0) {
      final h = secs ~/ 3600;
      final m = (secs % 3600) ~/ 60;
      final s = (secs % 60).toString().padLeft(2, '0');
      return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
    }
    final text = _usable(ep.info?.duration);
    if (text != null && RegExp(r'^\d{1,2}(:\d{2}){1,2}$').hasMatch(text)) {
      return text;
    }
    final minutes = art?.runtimeMinutes;
    return minutes != null && minutes > 0 ? '$minutes min' : null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeriesDetailTokens.background,
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
            final serie = snapshot.data;
            if (serie == null || serie.info == null) {
              return _DetailsErrorState(
                onBack: () => _popDetails(source: 'chrome'),
                onReload: _reload,
              );
            }
            return _buildPage(context, serie.info!);
          },
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, InfoSerie info) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    final s = compact ? 1.0 : (size.height / 540).clamp(0.85, 1.6);
    final side = compact ? 16.0 : 44.0 * s;
    final title = _seriesTitle;
    final art = _showArt;

    final backdrops = info.backdropPath ?? const <String>[];
    final backdrop =
        _usableImage(backdrops.isEmpty ? null : backdrops.first) ??
        _usableImage(art?.backdropUrl);
    final poster = _usableImage(info.cover) ?? _usableImage(art?.posterUrl);

    _seasonExtent = 128 * s;
    final cardWidth = compact ? 172.0 : 152.0 * s;
    _episodeExtent = cardWidth + 10 * s;

    return Stack(
      children: [
        Positioned.fill(
          child: SeriesBackdrop(title: title, imageUrl: backdrop),
        ),
        SafeArea(
          child: SingleChildScrollView(
            controller: _pageScroll,
            padding: EdgeInsets.only(
              top: (compact ? 10 : 20) * s,
              bottom: 20 * s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(s),
                      SizedBox(height: 10 * s),
                      _buildHeader(
                        info: info,
                        title: title,
                        poster: poster,
                        compact: compact,
                        wide: size.width >= 900,
                        s: s,
                      ),
                    ],
                  ),
                ),
                if (_seasons.isNotEmpty) ...[
                  SizedBox(height: 14 * s),
                  _buildSeasons(side, s),
                  Container(
                    height: 1,
                    margin: EdgeInsets.fromLTRB(side, 8 * s, side, 10 * s),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kColorPrimary.withValues(alpha: 0.05),
                          kColorPrimary.withValues(alpha: 0.75),
                          kColorPrimary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                  _buildEpisodes(side, cardWidth, s),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(double s) {
    final focused = _zone == _SerieZone.back;
    return Row(
      children: [
        GestureDetector(
          onTap: () => _popDetails(source: 'chrome'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36 * s,
            height: 36 * s,
            decoration: BoxDecoration(
              color: focused ? kColorPrimary : const Color(0x8C0A1220),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: focused
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.22),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              color: Colors.white,
              size: 24 * s,
            ),
          ),
        ),
        SizedBox(width: 16 * s),
        Icon(Icons.tv_rounded, color: kColorPrimary, size: 22 * s),
        SizedBox(width: 8 * s),
        Text(
          'Series',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17 * s,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required InfoSerie info,
    required String title,
    required String? poster,
    required bool compact,
    required bool wide,
    required double s,
  }) {
    final meta = _metaParts(info);
    final rating = _ratingText(info);
    final plot = _plotText(info);

    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: (compact ? 22 : 30) * s,
        fontWeight: FontWeight.w800,
        height: 1.1,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
      ),
    );
    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meta.isNotEmpty) ...[
          SizedBox(height: 8 * s),
          Text(
            meta.join('   |   '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SeriesDetailTokens.textSecondary,
              fontSize: 13 * s,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (rating != null) ...[
          SizedBox(height: 6 * s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: kColorAccentWarm, size: 17 * s),
              SizedBox(width: 4 * s),
              Text(
                rating,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5 * s,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' / 10',
                style: TextStyle(
                  color: SeriesDetailTokens.textMuted,
                  fontSize: 12 * s,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final Widget plotText = plot == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: 9 * s),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520 * s),
              child: Text(
                plot,
                maxLines: compact ? 5 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 12.5 * s,
                  height: 1.4,
                ),
              ),
            ),
          );
    final actions = _buildActions(s);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SeriesPoster(title: title, width: 104, imageUrl: poster),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [titleText, facts],
                ),
              ),
            ],
          ),
          plotText,
          const SizedBox(height: 14),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SeriesPoster(title: title, width: 132 * s, imageUrl: poster),
        SizedBox(width: 22 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleText,
              facts,
              plotText,
              if (!wide) ...[SizedBox(height: 12 * s), actions],
            ],
          ),
        ),
        if (wide) ...[SizedBox(width: 18 * s), actions],
      ],
    );
  }

  Widget _buildActions(double s) {
    final actions = _actions;
    final inZone = _zone == _SerieZone.actions;

    Widget button(
      int i, {
      required IconData icon,
      required String label,
      required VoidCallback run,
      bool primary = false,
      Color? iconColor,
    }) {
      return SeriesActionButton(
        icon: icon,
        label: label,
        primary: primary,
        iconColor: iconColor,
        focused: inZone && _actionIdx == i,
        scale: s,
        onTap: () {
          setState(() {
            _zone = _SerieZone.actions;
            _actionIdx = i;
          });
          run();
        },
      );
    }

    return BlocBuilder<WatchingCubit, WatchingState>(
      builder: (context, watch) {
        final resume = _resumePoint(watch);
        var playLabel = 'Play';
        if (resume != null) {
          final season = int.tryParse(_seasons[resume.seasonIdx]);
          final eps = _episodesOf(_seasons[resume.seasonIdx]);
          final ep = _episodeNumber(eps[resume.episodeIdx], resume.episodeIdx);
          playLabel = season == null ? 'Resume E$ep' : 'Resume S$season E$ep';
        }
        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, favState) {
            final liked = _isLiked(favState);
            return Wrap(
              spacing: 10 * s,
              runSpacing: 8 * s,
              children: [
                for (var i = 0; i < actions.length; i++)
                  switch (actions[i]) {
                    _SerieAction.play => button(
                      i,
                      icon: Icons.play_arrow_rounded,
                      label: playLabel,
                      primary: true,
                      run: _playPrimary,
                    ),
                    _SerieAction.myList => button(
                      i,
                      icon: liked ? Icons.favorite_rounded : Icons.add_rounded,
                      iconColor: liked ? Colors.redAccent : null,
                      label: liked ? 'In My List' : 'My List',
                      run: _toggleFavorite,
                    ),
                    _SerieAction.trailer => button(
                      i,
                      icon: Icons.movie_outlined,
                      label: 'Trailer',
                      run: _openTrailer,
                    ),
                  },
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSeasons(double side, double s) {
    return SizedBox(
      height: 44 * s,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: side, right: 18 * s),
            child: Text(
              'SEASONS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13 * s,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _seasonScroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: side),
              itemExtent: _seasonExtent,
              itemCount: _seasons.length,
              itemBuilder: (context, idx) => SeriesSeasonPill(
                label: 'Season ${_seasons[idx]}',
                selected: idx == _seasonIdx,
                focused: idx == _seasonIdx && _zone == _SerieZone.seasons,
                scale: s,
                onTap: () {
                  setState(() => _zone = _SerieZone.seasons);
                  _selectSeason(idx);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodes(double side, double cardWidth, double s) {
    final seasonKey = _seasons[_seasonIdx];
    final seasonNumber = int.tryParse(seasonKey);
    final stills = _seasonArt[seasonKey] ?? const <int, SeriesEpisodeArt>{};
    final count = _episodes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: Row(
            children: [
              Text(
                'EPISODES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '  –  Season $seasonKey',
                style: TextStyle(
                  color: SeriesDetailTokens.textSecondary,
                  fontSize: 13 * s,
                ),
              ),
              const Spacer(),
              if (count > 0)
                Text(
                  count == 1 ? '1 Episode' : '$count Episodes',
                  style: TextStyle(
                    color: SeriesDetailTokens.textSecondary,
                    fontSize: 12 * s,
                  ),
                ),
            ],
          ),
        ),
        if (count == 0)
          Padding(
            padding: EdgeInsets.fromLTRB(side, 16 * s, side, 16 * s),
            child: Text(
              'No episodes available for this season',
              style: TextStyle(
                color: SeriesDetailTokens.textMuted,
                fontSize: 13 * s,
              ),
            ),
          )
        else
          SizedBox(
            height: cardWidth * 9 / 16 + 88 * s,
            child: BlocBuilder<WatchingCubit, WatchingState>(
              builder: (context, watch) => ListView.builder(
                controller: _episodeScroll,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: EdgeInsets.only(left: side, right: side),
                itemExtent: _episodeExtent,
                itemCount: count,
                itemBuilder: (context, idx) {
                  final ep = _episodes[idx];
                  final number = _episodeNumber(ep, idx);
                  final art = stills[number];
                  final saved = _watchOf(watch, ep);
                  final progress = saved != null && saved.durationStrm > 0
                      ? (saved.sliderValue / saved.durationStrm).clamp(0.0, 1.0)
                      : null;
                  return Padding(
                    padding: EdgeInsets.only(top: 10 * s, right: 10 * s),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SeriesEpisodeCard(
                        episodeLabel: 'E$number',
                        seasonLabel: seasonNumber == null
                            ? ''
                            : 'Season $seasonNumber',
                        title:
                            _usable(art?.name) ??
                            _usable(ep.title) ??
                            'Episode $number',
                        stillUrl:
                            _usableImage(ep.info?.movieImage) ??
                            _usableImage(art?.stillUrl),
                        runtime: _runtimeText(ep, art),
                        progress: progress,
                        focused:
                            idx == _episodeIdx && _zone == _SerieZone.episodes,
                        selected: idx == _episodeIdx,
                        scale: s,
                        onTap: () {
                          setState(() {
                            _episodeIdx = idx;
                            _zone = _SerieZone.episodes;
                          });
                          _playEpisode();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
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
                      child: Icon(
                        FontAwesomeIcons.chevronLeft.data,
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
                      child: Icon(
                        FontAwesomeIcons.chevronLeft.data,
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
                    child: Icon(
                      FontAwesomeIcons.circleExclamation.data,
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
