import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'helpers/helpers.dart';
import 'logic/blocs/auth/auth_bloc.dart';
import 'logic/blocs/categories/channels/channels_bloc.dart';
import 'logic/blocs/categories/live_caty/live_caty_bloc.dart';
import 'logic/blocs/categories/movie_caty/movie_caty_bloc.dart';
import 'logic/blocs/categories/series_caty/series_caty_bloc.dart';
import 'logic/cubits/favorites/favorites_cubit.dart';
import 'logic/cubits/settings/settings_cubit.dart';
import 'logic/cubits/video/video_cubit.dart';
import 'logic/cubits/watch/watching_cubit.dart';
import 'presentation/screens/screens.dart';
import 'presentation/mobile/adult_content_screen.dart';
import 'presentation/tv/tv_search_screen.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized prior to loading services
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local GetStorage instances for state and favorites
  await GetStorage.init();
  await GetStorage.init("favorites");
  await GetStorage.init("preferences");
  await GetStorage.init("youtube_trailer_cache");

  final prefs = GetStorage("preferences");
  prefs.writeIfNull("allowMobileLandscape", false);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize device orientation
  await OrientationGuard.init();

  runApp(
    MyApp(
      iptv: IpTvApi(),
      authApi: AuthApi(),
      watchingLocale: WatchingLocale(),
      favoriteLocale: FavoriteLocale(),
    ),
  );
}

class MyApp extends StatefulWidget {
  final IpTvApi iptv;
  final AuthApi authApi;
  final WatchingLocale watchingLocale;
  final FavoriteLocale favoriteLocale;

  const MyApp({
    super.key,
    required this.iptv,
    required this.authApi,
    required this.watchingLocale,
    required this.favoriteLocale,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _configureSystemUI();
  }

  /// Configures system UI overlays for an immersive, distraction-free playback experience.
  void _configureSystemUI() {
    // ImmersiveSticky hides the status and navigation bars, making them only reveal
    // on a swipe gesture without shifting the layout underneath. Ideal for media players.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      // Map standard keyboard/remote control keys to native ActivateIntents for TV focus grids
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (context) => AuthBloc(widget.authApi)),
          BlocProvider<LiveCatyBloc>(
            create: (context) => LiveCatyBloc(widget.iptv),
          ),
          BlocProvider<ChannelsBloc>(
            create: (context) => ChannelsBloc(widget.iptv),
          ),
          BlocProvider<MovieCatyBloc>(
            create: (context) => MovieCatyBloc(widget.iptv),
          ),
          BlocProvider<SeriesCatyBloc>(
            create: (context) => SeriesCatyBloc(widget.iptv),
          ),
          BlocProvider<VideoCubit>(create: (context) => VideoCubit()),
          BlocProvider<SettingsCubit>(create: (context) => SettingsCubit()),
          BlocProvider<WatchingCubit>(
            create: (context) => WatchingCubit(widget.watchingLocale),
          ),
          BlocProvider<FavoritesCubit>(
            create: (context) => FavoritesCubit(widget.favoriteLocale),
          ),
        ],
        child: ResponsiveSizer(
          builder: (context, orient, type) {
            return GetMaterialApp(
              title: kAppName,
              theme: MyThemApp.themeData(context),
              debugShowCheckedModeBanner: false,
              initialRoute: "/",
              getPages: [
                GetPage(name: screenSplash, page: () => const SplashScreen()),
                GetPage(name: screenWelcome, page: () => const WelcomeScreen()),
                GetPage(name: screenIntro, page: () => const IntroScreen()),
                GetPage(
                  name: screenLiveCategories,
                  page: () => const LiveCategoriesScreen(),
                ),
                GetPage(
                  name: screenRegister,
                  page: () => const RegisterScreen(),
                ),
                GetPage(
                  name: screenRegisterTv,
                  page: () => const RegisterUserTv(),
                ),
                GetPage(
                  name: screenMovieCategories,
                  page: () => const MovieCategoriesScreen(),
                ),
                GetPage(
                  name: screenSeriesCategories,
                  page: () => const SeriesCategoriesScreen(),
                ),
                GetPage(
                  name: screenSettings,
                  page: () => const SettingsScreen(),
                ),
                GetPage(
                  name: screenConnectionTest,
                  page: () => const ConnectionTestScreen(),
                ),
                GetPage(
                  name: screenFavourite,
                  page: () => const FavouriteScreen(),
                ),
                GetPage(name: screenCatchUp, page: () => const CatchUpScreen()),
                GetPage(
                  name: screenAdultContent,
                  page: () => const AdultContentScreen(),
                ),
                GetPage(
                  name: screenTvSearch,
                  page: () => const TvSearchScreen(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
