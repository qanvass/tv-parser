import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:path_provider/path_provider.dart';

import '../models/category.dart';
import '../models/channel_live.dart';
import '../models/channel_serie.dart';
import '../models/epg.dart';
import '../models/movie_detail.dart';
import '../models/serie_details.dart';
import '../models/user.dart';
import '../models/watching.dart';

import 'm3u_parser.dart';
import 'catalog_perf.dart';
import 'apollo_native_catalog_session.dart';
import 'starlite_vod_m3u_session.dart';
import 'starlite_vod_m3u_urls.dart';
import '../provider/provider_capabilities.dart';
import '../provider/provider_capability_inspector.dart';
import '../provider/provider_capability_store.dart';
import '../provider/xtream_probe_url_builder.dart';
import '../epg/xmltv_repository.dart';
export 'playback_url_builder.dart';
export 'provider_curation_rules.dart';
export 'm3u_parser.dart';
export 'stream_health_service.dart';
export 'apollo_startup_show_api.dart';
export 'apollo_native_catalog_session.dart';
export 'starlite_vod_m3u_session.dart';
export 'starlite_vod_m3u_urls.dart';
export '../provider/provider_capabilities.dart';
export '../provider/provider_capability_inspector.dart';
export '../provider/provider_capability_store.dart';
export '../provider/provider_enums.dart';
export '../epg/xmltv_repository.dart';
export '../epg/xmltv_models.dart';

part '../locale/locale.dart';
part 'auth.dart';
part 'iptv.dart';
part 'iptv_provider_session.dart';
part '../locale/favorites.dart';

final _dio = Dio(
  BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ),
);
final locale = GetStorage();
final favoritesLocale = GetStorage("favorites");
