part of '../screens.dart';

class StreamPlayerPage extends StatefulWidget {
  const StreamPlayerPage({super.key, required this.controller});
  final VlcPlayerController? controller;

  @override
  State<StreamPlayerPage> createState() => _StreamPlayerPageState();
}

class _StreamPlayerPageState extends State<StreamPlayerPage> {
  bool isPlayed = true;

  bool showControllersVideo = true;
  late Timer timer;

  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'StreamPlayerRoot');
  final FocusNode _playPauseFocusNode = FocusNode(
    debugLabel: 'StreamPlayerPlayPause',
  );

  @override
  void initState() {
    //  Wakelock.enable();
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (showControllersVideo) {
        setState(() {
          showControllersVideo = false;
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    _rootFocusNode.dispose();
    _playPauseFocusNode.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (isPlayed) {
        widget.controller!.pause();
        isPlayed = false;
      } else {
        widget.controller!.play();
        isPlayed = true;
      }
    });
  }

  /// Handles D-pad / remote input so the live player is fully usable
  /// without a touchscreen (required for Android TV / Google TV).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Any remote press while controls are hidden: reveal them and hand
    // focus straight to play/pause so the next press can act immediately.
    if (!showControllersVideo) {
      setState(() {
        showControllersVideo = true;
      });
      _playPauseFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller == null) {
      return const Center(
        child: Text('Select a player...', style: TextStyle(color: Colors.grey)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Focus(
          focusNode: _rootFocusNode,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Ink(
            color: Colors.black,
            width: w,
            height: h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VlcPlayer(
                  controller: widget.controller!,
                  aspectRatio: w / h,
                  placeholder: const Center(child: CircularProgressIndicator()),
                ),

                GestureDetector(
                  onTap: () {
                    debugPrint("click");
                    setState(() {
                      showControllersVideo = !showControllersVideo;
                    });
                  },
                  child: Container(
                    width: w,
                    height: h,
                    color: Colors.transparent,
                  ),
                ),

                ///Controllers
                BlocBuilder<VideoCubit, VideoState>(
                  builder: (context, state) {
                    if (!state.isFull) {
                      return const SizedBox();
                    }

                    return SizedBox(
                      width: w,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: !showControllersVideo
                            ? const SizedBox()
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        child: IconButton(
                                          focusColor: kColorFocus,
                                          onPressed: () {
                                            context
                                                .read<VideoCubit>()
                                                .changeUrlVideo(false);
                                            //Get.back();
                                          },
                                          icon: Icon(
                                            FontAwesomeIcons.chevronRight.data,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    focusNode: _playPauseFocusNode,
                                    autofocus: true,
                                    focusColor: kColorFocus,
                                    onPressed: _togglePlayPause,
                                    icon: Icon(
                                      isPlayed
                                          ? FontAwesomeIcons.pause.data
                                          : FontAwesomeIcons.play.data,
                                      size: 24.sp,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
