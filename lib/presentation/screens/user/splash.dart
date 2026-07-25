part of '../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _videoInitialized = false;
  bool _videoCompleted = false;
  String? _nextScreenTarget;

  void _checkNavigation() {
    if (_videoCompleted && _nextScreenTarget != null) {
      OrientationGuard.applyDeviceOrientation();
      Get.offAndToNamed(_nextScreenTarget!);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OrientationGuard.init();
      context.read<SettingsCubit>().getSettingsCode();
      context.read<AuthBloc>().add(AuthGetUser());
    });

    // CRITICAL: DO NOT TOUCH THIS SPLASH SCREEN VIDEO PATH EVER. HARDCODED REQUIREMENT.
    _controller = VideoPlayerController.asset('assets/images/splash_video.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        // Keep sync — async then+catchError can drop errors on some devices.
        try {
          _controller?.setVolume(1.0);
        } catch (_) {}
        setState(() {
          _videoInitialized = true;
        });
        _controller?.play();
      }).catchError((e) {
        debugPrint("Splash video player load error: $e");
        // Fallback to instantly complete video if loading fails
        if (mounted) {
          setState(() {
            _videoCompleted = true;
          });
          _checkNavigation();
        }
      });

    _controller?.addListener(() {
      if (_controller != null &&
          _controller!.value.position >= _controller!.value.duration) {
        if (mounted && !_videoCompleted) {
          setState(() {
            _videoCompleted = true;
          });
          _checkNavigation();
        }
      }
    });

    // Safety fallback slightly past the 5s splash reel
    Future.delayed(const Duration(seconds: 6)).then((_) {
      if (mounted && !_videoCompleted) {
        setState(() {
          _videoCompleted = true;
        });
        _checkNavigation();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("width: ${MediaQuery.of(context).size.width}");
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthSuccess) {
                context.read<LiveCatyBloc>().add(GetLiveCategories());
                context.read<MovieCatyBloc>().add(GetMovieCategories());
                context.read<SeriesCatyBloc>().add(GetSeriesCategories());
                _nextScreenTarget = screenWelcome;
                _checkNavigation();
              } else if (state is AuthFailed) {
                if (isTv(context)) {
                  _nextScreenTarget = screenRegisterTv;
                } else {
                  _nextScreenTarget = screenIntro;
                }
                _checkNavigation();
              }
            },
            child: _videoInitialized
                ? _SplashVideoFrame(controller: _controller!)
                : const LoadingWidget(),
          );
        },
      ),
    );
  }
}

/// Full-bleed 16:9 splash. Uses contain so phone portrait letterboxes
/// cleanly; on TV panels the widescreen reel fills the frame.
class _SplashVideoFrame extends StatelessWidget {
  const _SplashVideoFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final videoSize = controller.value.size;
    final aspect = videoSize.width == 0 || videoSize.height == 0
        ? (16 / 9)
        : videoSize.width / videoSize.height;

    return ColoredBox(
      color: const Color(0xFF0F0F10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Slight overscan inset (~2%) so aurora edges aren't clipped on TVs.
          final maxW = constraints.maxWidth * 0.98;
          final maxH = constraints.maxHeight * 0.98;

          var width = maxW;
          var height = width / aspect;
          if (height > maxH) {
            height = maxH;
            width = height * aspect;
          }

          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(controller),
            ),
          );
        },
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = getSize(context);
    final logoSize = size.shortestSide * 0.45;
    return Container(
      width: size.width,
      height: size.height,
      decoration: kDecorBackground,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image(
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            image: const AssetImage(kIconSplash),
          ),
          const SizedBox(height: 10),
          Text(kAppName, style: Get.textTheme.displaySmall),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthLoading) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  child: const CircularProgressIndicator(),
                );
              } else if (state is AuthFailed) {
                return const Text('');
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }
}
