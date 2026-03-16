part of '../screens.dart';

// ─── Shared VOD constants / helpers (used by movie + series players) ──────────

const _kVodAspects = ['16:9', '4:3', '1:1', '21:9'];

bool _isSelectKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.gameButtonA;

// ─── Shared track-selection panel (Positioned, lives inside a Stack) ──────────

class _VodTrackPanel extends StatelessWidget {
  const _VodTrackPanel({
    required this.isSub,
    required this.list,
    required this.focusedIdx,
    required this.onSelect,
  });

  final bool isSub;
  final List<MapEntry<int, String>> list;
  final int focusedIdx;
  final void Function(int trackId) onSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      right: 16,
      child: Container(
        width: 220,
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: const Color(0xF0101018),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSub
                        ? FontAwesomeIcons.closedCaptioning
                        : FontAwesomeIcons.volumeHigh,
                    size: 12,
                    color: kColorPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSub ? 'SUBTITLES' : 'AUDIO TRACKS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final focused = i == focusedIdx;
                  return GestureDetector(
                    onTap: () => onSelect(list[i].key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? kColorPrimary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: focused ? kColorFocus : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        list[i].value.isNotEmpty
                            ? list[i].value
                            : 'Track ${i + 1}',
                        style: TextStyle(
                          color: focused ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: focused
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Player ──────────────────────────────────────────────────────────────
// Standalone fullscreen player for a single live channel.
// Used when launching from Favourites (or anywhere outside LiveCategoriesScreen).
//
// D-pad focus layout:
//   Row 0 (top bar):    0=Back  1=SUB  2=AUD
//   Row 1 (bottom bar): 0=Play/Pause  1=Aspect

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({
    super.key,
    required this.link,
    required this.title,
    this.streamIcon,
  });

  final String link;
  final String title;
  final String? streamIcon;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late VlcPlayerController _ctrl;

  bool _isPlaying = false;
  bool _isBuffering = true;

  bool _showControls = true;
  Timer? _hideTimer;

  Map<int, String> _audioTracks = {};
  Map<int, String> _subtitleTracks = {};
  bool _tracksLoaded = false;

  String? _trackPanel; // null | 'sub' | 'audio'
  int _trackPanelIdx = 0;

  int _aspectIdx = 0;

  int _focusRow = 1;
  int _focusCol = 0;
  final _focusNode = FocusNode();

  List<MapEntry<int, String>> get _trackList =>
      (_trackPanel == 'sub' ? _subtitleTracks : _audioTracks).entries.toList();

  @override
  void initState() {
    super.initState();
    _ctrl = VlcPlayerController.network(
      widget.link,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([VlcAdvancedOptions.networkCaching(2000)]),
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

  void _onVlc() {
    if (!mounted) return;
    final v = _ctrl.value;
    setState(() {
      _isPlaying = v.isPlaying;
      _isBuffering = !v.isInitialized || v.isBuffering;
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
      if (mounted)
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = sub;
        });
    } catch (_) {}
  }

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
    if (_isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
    _scheduleHide();
  }

  Future<void> _cycleAspect() async {
    final next = (_aspectIdx + 1) % _kVodAspects.length;
    try {
      await _ctrl.setVideoAspectRatio(_kVodAspects[next]);
    } catch (_) {}
    if (mounted) setState(() => _aspectIdx = next);
    _scheduleHide();
  }

  void _openTrackPanel(String type) {
    setState(() {
      _trackPanel = type;
      _trackPanelIdx = 0;
    });
    _hideTimer?.cancel();
  }

  void _selectTrack(int id) {
    try {
      if (_trackPanel == 'sub') {
        _ctrl.setSpuTrack(id);
      } else {
        _ctrl.setAudioTrack(id);
      }
    } catch (_) {}
    setState(() => _trackPanel = null);
    _scheduleHide();
  }

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (_trackPanel != null) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_trackPanelIdx > 0) setState(() => _trackPanelIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_trackPanelIdx < _trackList.length - 1)
          setState(() => _trackPanelIdx++);
      } else if (_isSelectKey(k)) {
        if (_trackList.isNotEmpty) _selectTrack(_trackList[_trackPanelIdx].key);
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _trackPanel = null);
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }

    if (!_showControls) {
      setState(() => _showControls = true);
      _scheduleHide();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusRow == 1)
        setState(() {
          _focusRow = 0;
          _focusCol = _focusCol.clamp(0, 2);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow == 0)
        setState(() {
          _focusRow = 1;
          _focusCol = _focusCol.clamp(0, 1);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      final maxCol = _focusRow == 0 ? 2 : 1;
      if (_focusCol < maxCol) setState(() => _focusCol++);
      _scheduleHide();
    } else if (_isSelectKey(k)) {
      _activate();
    } else if (k == LogicalKeyboardKey.escape) {
      Get.back();
    }
    return KeyEventResult.handled;
  }

  void _activate() {
    if (_focusRow == 0) {
      switch (_focusCol) {
        case 0:
          Get.back();
        case 1:
          if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
        case 2:
          if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
      }
    } else {
      switch (_focusCol) {
        case 0:
          _togglePlay();
        case 1:
          _cycleAspect();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.back();
      },
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
        children: [_buildTopBar(), const Spacer(), _buildBottomBar()],
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
              onTap: Get.back,
            ),
            const SizedBox(width: 8),
            if (widget.streamIcon != null && widget.streamIcon!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CachedNetworkImage(
                  imageUrl: widget.streamIcon!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty
                  ? '${_subtitleTracks.length}'
                  : null,
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

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              label: _isPlaying ? 'Pause' : 'Play',
              isFocused: _isFocused(1, 0),
              isLarge: true,
              onTap: _togglePlay,
            ),
            const Spacer(),
            _FsBtn(
              icon: FontAwesomeIcons.expand,
              label: _kVodAspects[_aspectIdx],
              isFocused: _isFocused(1, 1),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Movie Player ─────────────────────────────────────────────────────────────
// Full-screen VOD player for movies.
// Returns [positionSeconds, durationSeconds] on back for watch-history tracking.
//
// D-pad focus layout:
//   Row 0 (top bar):    0=Back  1=SUB  2=AUD
//   Row 1 (bottom bar): 0=-10s  1=Play  2=Aspect

class MoviePlayerScreen extends StatefulWidget {
  const MoviePlayerScreen({super.key, required this.link, required this.title});

  final String link;
  final String title;

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> {
  late VlcPlayerController _ctrl;

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

  // D-pad
  int _focusRow = 1;
  int _focusCol = 1; // default: Play/Pause
  final _focusNode = FocusNode();

  List<MapEntry<int, String>> get _trackList =>
      (_trackPanel == 'sub' ? _subtitleTracks : _audioTracks).entries.toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl = VlcPlayerController.network(
      widget.link,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([VlcAdvancedOptions.networkCaching(2000)]),
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
      if (mounted)
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = sub;
        });
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
    if (_isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
    _scheduleHide();
  }

  Future<void> _rewind10s() async {
    try {
      final t = _position - const Duration(seconds: 30);
      await _ctrl.seekTo(t < Duration.zero ? Duration.zero : t);
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _forward10s() async {
    try {
      final t = _position + const Duration(seconds: 30);
      await _ctrl.seekTo(t > _duration ? _duration : t);
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _cycleAspect() async {
    final next = (_aspectIdx + 1) % _kVodAspects.length;
    try {
      await _ctrl.setVideoAspectRatio(_kVodAspects[next]);
    } catch (_) {}
    if (mounted) setState(() => _aspectIdx = next);
    _scheduleHide();
  }

  void _openTrackPanel(String type) {
    setState(() {
      _trackPanel = type;
      _trackPanelIdx = 0;
    });
    _hideTimer?.cancel();
  }

  void _selectTrack(int id) {
    try {
      if (_trackPanel == 'sub') {
        _ctrl.setSpuTrack(id);
      } else {
        _ctrl.setAudioTrack(id);
      }
    } catch (_) {}
    setState(() => _trackPanel = null);
    _scheduleHide();
  }

  void _goBack() {
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    Get.back(result: pos > 0 ? [pos, dur] : null);
  }

  // ── D-pad ─────────────────────────────────────────────────────────────────

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // Track panel open
    if (_trackPanel != null) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_trackPanelIdx > 0) setState(() => _trackPanelIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_trackPanelIdx < _trackList.length - 1)
          setState(() => _trackPanelIdx++);
      } else if (_isSelectKey(k)) {
        if (_trackList.isNotEmpty) _selectTrack(_trackList[_trackPanelIdx].key);
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.arrowLeft) {
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
      if (_focusRow == 1)
        setState(() {
          _focusRow = 0;
          _focusCol = _focusCol.clamp(0, 2);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow == 0)
        setState(() {
          _focusRow = 1;
          _focusCol = _focusCol.clamp(0, 3);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      final maxCol = _focusRow == 0 ? 2 : 3;
      if (_focusCol < maxCol) setState(() => _focusCol++);
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
        case 0:
          _goBack();
        case 1:
          if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
        case 2:
          if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
      }
    } else {
      switch (_focusCol) {
        case 0:
          _rewind10s();
        case 1:
          _togglePlay();
        case 2:
          _forward10s();
        case 3:
          _cycleAspect();
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
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
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
                  // ── Video ────────────────────────────────────────────
                  VlcPlayer(
                    controller: _ctrl,
                    aspectRatio: ratio,
                    placeholder: const SizedBox(),
                  ),

                  // ── Tap toggle ───────────────────────────────────────
                  GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),

                  // ── Buffering ────────────────────────────────────────
                  if (_isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),

                  // ── Controls overlay ─────────────────────────────────
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _buildOverlay(),
                    ),
                  ),

                  // ── Track panel ──────────────────────────────────────
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
        children: [_buildTopBar(), const Spacer(), _buildBottomBar()],
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
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty
                  ? '${_subtitleTracks.length}'
                  : null,
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
              isFocused: _isFocused(1, 0),
              onTap: _rewind10s,
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              label: '',
              isFocused: _isFocused(1, 1),
              isLarge: true,
              onTap: _togglePlay,
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.rotateRight,
              label: '',
              isFocused: _isFocused(1, 2),
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
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 0,
                        ),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: pos,
                        onChanged: (v) async {
                          try {
                            await _ctrl.seekTo(
                              Duration(milliseconds: (v * totalMs).round()),
                            );
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
              isFocused: _isFocused(1, 3),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }
}
