part of '../screens.dart';

// ─── Series Player ────────────────────────────────────────────────────────────
// Full-screen VOD player for series episodes.
// Prev/Next episode navigation row above the main controls.
// Saves watch progress to WatchingCubit on episode change and on back.
//
// D-pad focus layout:
//   Row 0 (top bar):     0=Back  1=SUB  2=AUD
//   Row 1 (episode nav): 0=Prev  1=Next
//   Row 2 (bottom bar):  0=-10s  1=Play  2=Aspect

class SeriesPlayerScreen extends StatefulWidget {
  const SeriesPlayerScreen({
    super.key,
    required this.episodes,
    required this.initialIdx,
    required this.serverUrl,
    required this.username,
    required this.password,
    this.seriesCover = '',
  });

  final List<Episode> episodes;
  final int initialIdx;
  final String serverUrl;
  final String username;
  final String password;
  final String seriesCover;

  @override
  State<SeriesPlayerScreen> createState() => _SeriesPlayerScreenState();
}

class _SeriesPlayerScreenState extends State<SeriesPlayerScreen> {
  late VlcPlayerController _ctrl;
  late int _epIdx;

  // Playback state
  bool _isPlaying = false;
  bool _isBuffering = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Controls visibility
  bool _showControls = true;
  Timer? _hideTimer;

  // Tracks
  Map<int, String> _audioTracks = {};
  Map<int, String> _subtitleTracks = {};
  bool _tracksLoaded = false;

  // Track panel
  String? _trackPanel; // null | 'sub' | 'audio'
  int _trackPanelIdx = 0;

  // Aspect ratio
  int _aspectIdx = 0;

  // D-pad: 3 rows — 0=top, 1=episode nav, 2=bottom
  int _focusRow = 2;
  int _focusCol = 1; // default: Play
  final _focusNode = FocusNode();

  Episode get _currentEp => widget.episodes[_epIdx];

  String get _currentUrl =>
      '${widget.serverUrl}/series/${widget.username}/${widget.password}/${_currentEp.id}.${_currentEp.containerExtension}';

  List<MapEntry<int, String>> get _trackList =>
      (_trackPanel == 'sub' ? _subtitleTracks : _audioTracks).entries.toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _epIdx = widget.initialIdx;
    _ctrl = VlcPlayerController.network(
      _currentUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
        ]),
      ),
    );
    _ctrl.addListener(_onVlc);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void deactivate() {
    try {
      _ctrl.pause();
      _ctrl.stop();
    } catch (_) {}
    super.deactivate();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onVlc);
    _hideTimer?.cancel();
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ctrl.stopRendererScanning().catchError((_) {});
    _ctrl.dispose();
    super.dispose();
  }

  // ── VLC listener ──────────────────────────────────────────────────────────

  void _onVlc() {
    if (!mounted) return;
    final v = _ctrl.value;
    setState(() {
      _isPlaying = v.isPlaying;
      _isBuffering = !v.isInitialized || v.isBuffering;
      _position = v.position;
      _duration = v.duration;
    });
    if (v.isInitialized && !_tracksLoaded) {
      _tracksLoaded = true;
      _loadTracks();
    }
  }

  Future<void> _loadTracks() async {
    try {
      final audio = await _ctrl.getAudioTracks();
      final sub = await _ctrl.getSpuTracks();
      if (mounted) setState(() { _audioTracks = audio; _subtitleTracks = sub; });
    } catch (_) {}
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_trackPanel != null) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  void _togglePlay() {
    if (_isPlaying) { _ctrl.pause(); } else { _ctrl.play(); }
    _scheduleHide();
  }

  Future<void> _rewind10s() async {
    try {
      final t = _position - const Duration(seconds: 10);
      await _ctrl.seekTo(t < Duration.zero ? Duration.zero : t);
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _forward10s() async {
    try {
      final t = _position + const Duration(seconds: 10);
      await _ctrl.seekTo(t > _duration ? _duration : t);
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _cycleAspect() async {
    final next = (_aspectIdx + 1) % _kVodAspects.length;
    try { await _ctrl.setVideoAspectRatio(_kVodAspects[next]); } catch (_) {}
    if (mounted) setState(() => _aspectIdx = next);
    _scheduleHide();
  }

  void _openTrackPanel(String type) {
    setState(() { _trackPanel = type; _trackPanelIdx = 0; });
    _hideTimer?.cancel();
  }

  void _selectTrack(int id) {
    try {
      if (_trackPanel == 'sub') { _ctrl.setSpuTrack(id); } else { _ctrl.setAudioTrack(id); }
    } catch (_) {}
    setState(() => _trackPanel = null);
    _scheduleHide();
  }

  void _saveProgress() {
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (pos <= 0) return;
    final ep = _currentEp;
    context.read<WatchingCubit>().addSerie(
      WatchingModel(
        sliderValue: pos,
        durationStrm: dur,
        stream: _currentUrl,
        title: ep.title ?? 'Episode ${_epIdx + 1}',
        image: ep.info?.movieImage ?? widget.seriesCover,
        streamId: ep.id.toString(),
      ),
    );
  }

  Future<void> _switchEpisode(int newIdx) async {
    if (newIdx < 0 || newIdx >= widget.episodes.length) return;
    _saveProgress();
    final newEp = widget.episodes[newIdx];
    final newUrl =
        '${widget.serverUrl}/series/${widget.username}/${widget.password}/${newEp.id}.${newEp.containerExtension}';
    setState(() {
      _epIdx = newIdx;
      _isBuffering = true;
      _tracksLoaded = false;
      _audioTracks = {};
      _subtitleTracks = {};
      _trackPanel = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _aspectIdx = 0;
    });
    try {
      await _ctrl.setMediaFromNetwork(newUrl, autoPlay: true, hwAcc: HwAcc.full);
    } catch (_) {}
    _scheduleHide();
  }

  void _goBack() {
    _saveProgress();
    Get.back();
  }

  // ── D-pad ─────────────────────────────────────────────────────────────────

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  int _maxColForRow(int row) => row == 1 ? 1 : (row == 0 ? 2 : 3);

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // Track panel open
    if (_trackPanel != null) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_trackPanelIdx > 0) setState(() => _trackPanelIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_trackPanelIdx < _trackList.length - 1) setState(() => _trackPanelIdx++);
      } else if (_isSelectKey(k)) {
        if (_trackList.isNotEmpty) _selectTrack(_trackList[_trackPanelIdx].key);
      } else if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _trackPanel = null);
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }

    // Controls hidden: any key shows them
    if (!_showControls) {
      setState(() => _showControls = true);
      _scheduleHide();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusRow > 0) setState(() { _focusRow--; _focusCol = _focusCol.clamp(0, _maxColForRow(_focusRow)); });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow < 2) setState(() { _focusRow++; _focusCol = _focusCol.clamp(0, _maxColForRow(_focusRow)); });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (_focusCol < _maxColForRow(_focusRow)) setState(() => _focusCol++);
      _scheduleHide();
    } else if (_isSelectKey(k)) {
      _activate();
    } else if (k == LogicalKeyboardKey.escape) {
      _goBack();
    }
    return KeyEventResult.handled;
  }

  void _activate() {
    if (_focusRow == 0) {
      switch (_focusCol) {
        case 0: _goBack();
        case 1: if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
        case 2: if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
      }
    } else if (_focusRow == 1) {
      switch (_focusCol) {
        case 0: if (_epIdx > 0) _switchEpisode(_epIdx - 1);
        case 1: if (_epIdx < widget.episodes.length - 1) _switchEpisode(_epIdx + 1);
      }
    } else {
      switch (_focusCol) {
        case 0: _rewind10s();
        case 1: _togglePlay();
        case 2: _forward10s();
        case 3: _cycleAspect();
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final ratio = constraints.maxWidth / constraints.maxHeight;
              return Stack(
                children: [
                  VlcPlayer(
                    controller: _ctrl,
                    aspectRatio: ratio,
                    placeholder: const SizedBox(),
                  ),
                  GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                  if (_isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _buildOverlay(),
                    ),
                  ),
                  if (_trackPanel != null)
                    _VodTrackPanel(
                      isSub: _trackPanel == 'sub',
                      list: _trackList,
                      focusedIdx: _trackPanelIdx,
                      onSelect: _selectTrack,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          _buildEpisodeNavRow(),
          const SizedBox(height: 8),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _FsBtn(
              icon: FontAwesomeIcons.chevronLeft,
              label: 'Back',
              isFocused: _isFocused(0, 0),
              onTap: _goBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentEp.title ?? 'Episode ${_epIdx + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Episode ${_epIdx + 1} of ${widget.episodes.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty ? '${_subtitleTracks.length}' : null,
              isFocused: _isFocused(0, 1),
              isDisabled: _subtitleTracks.isEmpty,
              onTap: () => _openTrackPanel('sub'),
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.volumeHigh,
              label: 'AUD',
              badge: _audioTracks.isNotEmpty ? '${_audioTracks.length}' : null,
              isFocused: _isFocused(0, 2),
              isDisabled: _audioTracks.isEmpty,
              onTap: () => _openTrackPanel('audio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeNavRow() {
    final hasPrev = _epIdx > 0;
    final hasNext = _epIdx < widget.episodes.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FsBtn(
            icon: FontAwesomeIcons.chevronLeft,
            label: 'Prev',
            isFocused: _isFocused(1, 0),
            isDisabled: !hasPrev,
            onTap: hasPrev ? () => _switchEpisode(_epIdx - 1) : () {},
          ),
          const Spacer(),
          Text(
            'Episode ${_epIdx + 1} / ${widget.episodes.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _FsBtn(
            icon: FontAwesomeIcons.chevronRight,
            label: 'Next',
            isFocused: _isFocused(1, 1),
            isDisabled: !hasNext,
            onTap: hasNext ? () => _switchEpisode(_epIdx + 1) : () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalMs = _duration.inMilliseconds;
    final pos = totalMs > 0
        ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _FsBtn(
              icon: FontAwesomeIcons.rotateLeft,
              label: '',
              isFocused: _isFocused(2, 0),
              onTap: _rewind10s,
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              label: '',
              isFocused: _isFocused(2, 1),
              isLarge: true,
              onTap: _togglePlay,
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.rotateRight,
              label: '',
              isFocused: _isFocused(2, 2),
              onTap: _forward10s,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    _fmt(_position),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kColorPrimary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: kColorFocus,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: pos,
                        onChanged: (v) async {
                          try {
                            await _ctrl.seekTo(Duration(milliseconds: (v * totalMs).round()));
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(_duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _FsBtn(
              icon: FontAwesomeIcons.expand,
              label: _kVodAspects[_aspectIdx],
              isFocused: _isFocused(2, 3),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }
}
