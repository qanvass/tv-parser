part of '../screens.dart';

class CatchUpScreen extends StatefulWidget {
  const CatchUpScreen({super.key});

  @override
  State<CatchUpScreen> createState() => _CatchUpScreenState();
}

class _CatchUpScreenState extends State<CatchUpScreen> {
  // panel: 1 = sidebar, 2 = content
  int _panel = 1;
  int _tabIdx = 0; // 0=Movies, 1=Series

  bool _appbarActive = false;
  int _appbarIdx = 0;
  static const int _appbarBtnMax = 0; // back only

  int _movieIdx = 0;
  int _serieIdx = 0;

  static const int _gridCols = 3;

  final _movieScroll = ScrollController();
  final _serieScroll = ScrollController();
  final _navFocus = FocusNode();

  @override
  void dispose() {
    _movieScroll.dispose();
    _serieScroll.dispose();
    _navFocus.dispose();
    super.dispose();
  }

  int get _currentIdx => _tabIdx == 0 ? _movieIdx : _serieIdx;

  void _setCurrentIdx(int v) {
    setState(() {
      if (_tabIdx == 0) _movieIdx = v;
      else _serieIdx = v;
    });
  }

  int _getCount() {
    final s = context.read<WatchingCubit>().state;
    return _tabIdx == 0 ? s.movies.length : s.series.length;
  }

  ScrollController get _activeScroll => _tabIdx == 0 ? _movieScroll : _serieScroll;

  void _scrollContentTo(int idx) {
    final sc = _activeScroll;
    if (!sc.hasClients) return;
    final row = idx ~/ _gridCols;
    const itemH = 180.0;
    final target = (row * itemH).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  /// Android TV remotes send [LogicalKeyboardKey.goBack]; emulators/desktop often
  /// send [LogicalKeyboardKey.escape]. Both must pop this route — returning
  /// [KeyEventResult.handled] for goBack without [Get.back] swallows Back and
  /// can finish the Activity (Google TV Home) instead of returning to the shell.
  bool _isBackKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack;

  void _popToShell() {
    // Guard against double-pop (Focus goBack + system Back in one frame)
    // which finishes MainActivity → Google TV Home.
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Get.back();
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // ── Appbar ─────────────────────────────────────────────────────────────
    if (_appbarActive) {
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() => _appbarActive = false);
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        if (_appbarIdx > 0) setState(() => _appbarIdx--);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        if (_appbarIdx < _appbarBtnMax) setState(() => _appbarIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        if (_appbarIdx == 0) _popToShell();
      } else if (_isBackKey(k)) {
        _popToShell();
      }
      return KeyEventResult.handled;
    }

    // ── Sidebar ────────────────────────────────────────────────────────────
    if (_panel == 1) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_tabIdx > 0) {
          setState(() => _tabIdx--);
        } else {
          setState(() { _appbarActive = true; _appbarIdx = 0; });
        }
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_tabIdx < 1) setState(() => _tabIdx++);
      } else if (k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        setState(() => _panel = 2);
      } else if (_isBackKey(k)) {
        _popToShell();
      }
      return KeyEventResult.handled;
    }

    // ── Content ────────────────────────────────────────────────────────────
    if (_panel == 2) {
      final idx = _currentIdx;
      final count = _getCount();

      if (k == LogicalKeyboardKey.arrowLeft) {
        if (idx % _gridCols == 0) {
          setState(() => _panel = 1);
        } else {
          _setCurrentIdx(idx - 1);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        if (idx < count - 1 && (idx + 1) % _gridCols != 0) {
          _setCurrentIdx(idx + 1);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (idx < _gridCols) {
          setState(() => _panel = 1);
        } else {
          _setCurrentIdx(idx - _gridCols);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        if (idx + _gridCols < count) {
          _setCurrentIdx(idx + _gridCols);
          _scrollContentTo(_currentIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _handleSelect();
        return KeyEventResult.handled;
      }
      if (_isBackKey(k)) {
        _popToShell();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_isBackKey(k)) {
      _popToShell();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleSelect() {
    final state = context.read<WatchingCubit>().state;
    final watchingCubit = context.read<WatchingCubit>();

    if (_tabIdx == 0) {
      final items = state.movies;
      if (_movieIdx >= items.length) return;
      final model = items[_movieIdx];
      Get.to(() => MoviePlayerScreen(link: model.stream, title: model.title))
          ?.then((result) {
        if (result != null) {
          watchingCubit.addMovie(WatchingModel(
            streamId: model.streamId,
            image: model.image,
            title: model.title,
            stream: model.stream,
            sliderValue: result[0],
            durationStrm: result[1],
          ));
        }
      });
    } else {
      final items = state.series;
      if (_serieIdx >= items.length) return;
      final model = items[_serieIdx];
      Get.to(() => MoviePlayerScreen(link: model.stream, title: model.title))
          ?.then((result) {
        if (result != null) {
          watchingCubit.addSerie(WatchingModel(
            streamId: model.streamId,
            image: model.image,
            title: model.title,
            stream: model.stream,
            sliderValue: result[0],
            durationStrm: result[1],
          ));
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Match Settings: Focus-only Back (no PopScope). PopScope(canPop:false)
    // + Focus goBack both calling Get.back() double-popped → Google TV Home.
    return Focus(
      focusNode: _navFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Ink(
          decoration: kDecorBackground,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: IptvAppBar(
                    title: 'Catch Up',
                    icon: FontAwesomeIcons.rotate.data,
                    onBack: _popToShell,
                    focusedIndex: _appbarActive ? _appbarIdx : null,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 190, child: _buildSidebar()),
                    Container(width: 1, color: kColorCardLight),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final labels = ['Movies', 'Series'];
    final icons = [FontAwesomeIcons.film.data, FontAwesomeIcons.clapperboard.data];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Text(
            'SECTIONS',
            style: Get.textTheme.bodySmall!.copyWith(
              color: kColorHint,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        ...List.generate(2, (i) {
          final isSelected = _tabIdx == i;
          final isFocused = isSelected && _panel == 1;
          return GestureDetector(
            onTap: () => setState(() { _tabIdx = i; _panel = 2; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? kColorPrimary.withValues(alpha: .18)
                    : kColorCardLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused
                      ? kColorFocus
                      : isSelected
                      ? kColorPrimary.withValues(alpha: .5)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(color: kColorFocus.withValues(alpha: .25), blurRadius: 8)]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    icons[i],
                    size: 14,
                    color: isSelected ? kColorPrimary : Colors.white38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels[i],
                      style: Get.textTheme.bodySmall!.copyWith(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: kColorFocus,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContent() {
    return BlocBuilder<WatchingCubit, WatchingState>(
      builder: (context, state) {
        final items = _tabIdx == 0 ? state.movies : state.series;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kColorPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: kColorPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    _tabIdx == 0 ? FontAwesomeIcons.film.data : FontAwesomeIcons.clapperboard.data,
                    size: 32,
                    color: kColorPrimary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _tabIdx == 0
                      ? 'No movies in progress'
                      : 'No series in progress',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final sc = _tabIdx == 0 ? _movieScroll : _serieScroll;
        final selectedIdx = _tabIdx == 0 ? _movieIdx : _serieIdx;

        return GridView.builder(
          controller: sc,
          cacheExtent: 350.0,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridCols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final model = items[i];
            final isSelected = i == selectedIdx;
            final isFocused = isSelected && _panel == 2;
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_tabIdx == 0) _movieIdx = i;
                  else _serieIdx = i;
                  _panel = 2;
                });
                _handleSelect();
              },
              child: _CatchUpItem(
                model: model,
                isSelected: isSelected,
                isFocused: isFocused,
                episodeLabel: _tabIdx == 1 ? 'Episode ${i + 1}' : null,
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Catch Up item card ────────────────────────────────────────────────────────

class _CatchUpItem extends StatelessWidget {
  const _CatchUpItem({
    required this.model,
    required this.isSelected,
    required this.isFocused,
    this.episodeLabel,
  });

  final WatchingModel model;
  final bool isSelected;
  final bool isFocused;
  final String? episodeLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: kColorCardDark,
        border: Border.all(
          color: isFocused
              ? kColorFocus
              : isSelected
              ? kColorPrimary.withValues(alpha: .5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isFocused
            ? [BoxShadow(color: kColorFocus.withValues(alpha: .4), blurRadius: 12, spreadRadius: 2)]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            CachedNetworkImage(
              imageUrl: model.image,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              placeholder: (_, __) => Container(
                color: kColorCardDark,
                child: const Center(
                  child: CircularProgressIndicator(color: kColorPrimary, strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: kColorCardDark,
                child: Center(
                  child: Image.asset(kIconSplash, width: 36, height: 36),
                ),
              ),
            ),
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .80),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            // Play icon (center, visible when focused)
            if (isFocused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kColorFocus,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: kColorFocus.withValues(alpha: .5), blurRadius: 12)],
                  ),
                  child: Icon(FontAwesomeIcons.play.data, color: Colors.white, size: 16),
                ),
              ),
            // Title + progress bar at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (episodeLabel != null)
                          Text(
                            episodeLabel!,
                            style: TextStyle(
                              color: kColorPrimary.withValues(alpha: .9),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          model.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  SizedBox(
                    height: 3,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (model.sliderValue * 10).round().clamp(0, 100),
                          child: Container(color: kColorPrimary),
                        ),
                        Expanded(
                          flex: (model.durationStrm * 10).round().clamp(0, 100),
                          child: Container(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}