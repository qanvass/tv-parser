part of 'helpers.dart';

const String kAppName = "TV Parser";

const String kIconLive = "assets/images/live-stream.png";
const String kIconSeries = "assets/images/clapperboard.png";
const String kIconMovies = "assets/images/film-reel.png";
const String kIconSplash = "assets/images/app_icon.png";
const String kIconLogoTransparent =
    "assets/images/tv_parser_logo_transparent.png";
const String kPrivacy = "https://tvparser.com/privacy";
const String kContact = "support@gopaygent.com";

const String kDemoUrl =
    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4";

const double sizeTablet = 950;

enum TypeCategory { all, live, movies, series }

Size getSize(BuildContext context) => MediaQuery.of(context).size;

bool isTv(BuildContext context) {
  return OrientationGuard.isTv;
}
