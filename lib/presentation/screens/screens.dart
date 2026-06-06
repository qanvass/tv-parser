import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';

import 'package:android_tv_text_field/native_textfield_tv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
//import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:cast/cast.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';

//import 'package:wakelock/wakelock.dart';

import '../../helpers/helpers.dart';
import '../../logic/blocs/auth/auth_bloc.dart';
import '../../logic/blocs/categories/channels/channels_bloc.dart';
import '../../logic/blocs/categories/live_caty/live_caty_bloc.dart';
import '../../logic/blocs/categories/movie_caty/movie_caty_bloc.dart';
import '../../logic/blocs/categories/series_caty/series_caty_bloc.dart';
import '../../logic/cubits/favorites/favorites_cubit.dart';
import '../../logic/cubits/settings/settings_cubit.dart';
import '../../logic/cubits/video/video_cubit.dart';
import '../../logic/cubits/watch/watching_cubit.dart';
import '../../repository/api/api.dart';
import '../../repository/models/user_preference_profile.dart';
import '../../repository/api/location_preference_service.dart';
import '../../repository/api/local_market_service.dart';
import '../../repository/api/cast_compatibility_service.dart';
import '../../repository/api/cast_media_service.dart';
import '../../repository/api/search_index_service.dart';
import '../../repository/api/ai_intent_mapper.dart';

import '../../repository/models/category.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/movie_detail.dart';
import '../../repository/models/serie_details.dart';

import '../../repository/models/watching.dart';
import '../widgets/widgets.dart';
import '../widgets/premium_channel_card.dart';
import '../shared/widgets/stream_launcher.dart';
import '../tv/tv_dashboard_shell.dart';
import '../mobile/mobile_watch_screen.dart';
import '../mobile/mobile_detail_screen.dart';

part 'live/live_categories.dart';
part 'movie/movie_categories.dart';
part 'movie/movie_details.dart';
part 'player/player_video.dart';
part 'player/movie_player.dart';
part 'player/series_player.dart';
part 'player/cast_dialog.dart';
part 'series/serie_details.dart';
part 'series/serie_seasons.dart';
part 'series/series_categories.dart';
part 'user/register.dart';
part 'user/register_tv.dart';
part 'user/settings.dart';
part 'user/splash.dart';
part 'user/intro.dart';
part 'user/favourites.dart';
part 'welcome.dart';
part 'user/catch_up.dart';
part 'user/connection_test.dart';

Map<String, int> getStreamQualityBuffers({required bool isLive}) {
  try {
    final box = GetStorage("preferences");
    final mode = box.read("stream_quality") ?? "Balanced";
    if (mode == "Fast Start") {
      return {
        "network": isLive ? 1500 : 4000,
        "live": isLive ? 1500 : 4000,
        "file": isLive ? 1500 : 4000,
      };
    } else if (mode == "Smooth Playback") {
      return {
        "network": isLive ? 3500 : 8000,
        "live": isLive ? 3500 : 8000,
        "file": isLive ? 3500 : 8000,
      };
    } else {
      // Balanced (Default)
      return {
        "network": isLive ? 2500 : 6000,
        "live": isLive ? 2500 : 6000,
        "file": isLive ? 2500 : 6000,
      };
    }
  } catch (_) {
    return {
      "network": isLive ? 2500 : 6000,
      "live": isLive ? 2500 : 6000,
      "file": isLive ? 2500 : 6000,
    };
  }
}

class SandTimeclock extends StatefulWidget {
  final double size;
  const SandTimeclock({super.key, this.size = 38.0});

  @override
  State<SandTimeclock> createState() => _SandTimeclockState();
}

class _SandTimeclockState extends State<SandTimeclock> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0.0, end: 0.5).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.85, curve: Curves.easeInOutBack),
        ),
      ),
      child: Icon(
        Icons.hourglass_bottom_rounded,
        color: const Color(0xFFFFC107),
        size: widget.size,
      ),
    );
  }
}
