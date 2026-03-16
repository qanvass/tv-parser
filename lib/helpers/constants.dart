part of 'helpers.dart';

const String kAppName = "AZUL IPTV";

//TODO: Force TV mode for testing on mobile ( true / false )
const bool kForceTvMode = false;

const String kIconLive = "assets/images/live-stream.png";
const String kIconSeries = "assets/images/clapperboard.png";
const String kIconMovies = "assets/images/film-reel.png";
const String kIconSplash = "assets/images/icon.png";
const String kImageIntro = "assets/images/intro h.jpeg";

const String kPrivacy = "https://www.whmcssmarters.com/terms-of-service/";
const String kContact = "https://mouadzizi.me";

const String kDemoUrl =
    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4";

const double sizeTablet = 950;

enum TypeCategory { all, live, movies, series }

Size getSize(BuildContext context) => MediaQuery.of(context).size;

bool isTv(BuildContext context) {
  if (kForceTvMode) return true;
  return MediaQuery.of(context).size.width > sizeTablet;
}
