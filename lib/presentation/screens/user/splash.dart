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
        if (mounted) {
          setState(() {
            _videoInitialized = true;
          });
          _controller?.play();
        }
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

    // Safety fallback timer (5 seconds) to ensure the app never hangs
    Future.delayed(const Duration(seconds: 5)).then((_) {
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
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : const LoadingWidget(),
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
    return Container(
      width: getSize(context).width,
      height: getSize(context).height,
      decoration: kDecorBackground,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image(
            width: getSize(context).height * .22,
            height: getSize(context).height * .22,
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
