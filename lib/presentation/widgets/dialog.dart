part of 'widgets.dart';

class DialogTrailerYoutube extends StatefulWidget {
  const DialogTrailerYoutube({
    super.key,
    required this.trailer,
    this.thumb,
    this.title,
  });

  final String trailer;
  final String? thumb;
  final String? title;

  @override
  State<DialogTrailerYoutube> createState() => _DialogTrailerYoutubeState();
}

class _DialogTrailerYoutubeState extends State<DialogTrailerYoutube> {
  late final PodPlayerController _controller;
  final _focusNode = FocusNode();

  // 0 = play/pause, 1 = close
  int _focusedBtn = 0;

  @override
  void initState() {
    super.initState();
    _controller = PodPlayerController(
      playVideoFrom: PlayVideoFrom.youtube(
        'https://youtu.be/${widget.trailer}',
      ),
      podPlayerConfig: const PodPlayerConfig(
        autoPlay: false,
        isLooping: false,
      ),
    )..initialise();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusedBtn > 0) setState(() => _focusedBtn--);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_focusedBtn < 1) setState(() => _focusedBtn++);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_focusedBtn == 0) {
        _togglePlay();
      } else {
        Get.back();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _togglePlay() {
    setState(() {
      if (_controller.isVideoPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller.isVideoPlaying;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Trailer pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              kColorPrimary.withValues(alpha: 0.18),
                              kColorPrimaryDark.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: kColorPrimary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FontAwesomeIcons.youtube.data,
                              size: 12,
                              color: kColorPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TRAILER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.title != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      // Close button
                      GestureDetector(
                        onTap: Get.back,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                          ),
                          child: Icon(
                            FontAwesomeIcons.xmark.data,
                            color: Colors.white54,
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Video player ──────────────────────────────────────
                SizedBox(
                  height: 200,
                  child: PodVideoPlayer(
                    controller: _controller,
                    alwaysShowProgressBar: false,
                    onToggleFullScreen: (value) async {
                      if (!value) {
                        OrientationGuard.applyPlayerExitOrientation();
                      }
                    },
                    podProgressBarConfig: const PodProgressBarConfig(
                      alwaysVisibleCircleHandler: false,
                      circleHandlerColor: kColorPrimary,
                      playingBarColor: kColorPrimary,
                    ),
                    videoThumbnail: widget.thumb == null
                        ? null
                        : DecorationImage(
                            image: NetworkImage(widget.thumb!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                // ── Bottom controls ───────────────────────────────────
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Play / Pause
                      _DialogBtn(
                        icon: isPlaying
                            ? FontAwesomeIcons.pause.data
                            : FontAwesomeIcons.play.data,
                        label: isPlaying ? 'Pause' : 'Play',
                        isFocused: _focusedBtn == 0,
                        isPrimary: true,
                        onTap: _togglePlay,
                      ),
                      SizedBox(width: 12),
                      // Close
                      _DialogBtn(
                        icon: FontAwesomeIcons.xmark.data,
                        label: 'Close',
                        isFocused: _focusedBtn == 1,
                        isPrimary: false,
                        onTap: Get.back,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dialog action button ──────────────────────────────────────────────────────

class _DialogBtn extends StatelessWidget {
  const _DialogBtn({
    required this.icon,
    required this.label,
    required this.isFocused,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isFocused;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? kColorPrimary : Colors.white38;
    final focusColor = isPrimary ? kColorFocus : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isFocused
              ? (isPrimary ? kColorPrimary : Colors.white.withValues(alpha: 0.1))
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? focusColor : Colors.white.withValues(alpha: 0.08),
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: focusColor.withValues(alpha: 0.3), blurRadius: 8)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isFocused ? Colors.white : color,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isFocused ? Colors.white : color,
                fontSize: 12,
                fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
