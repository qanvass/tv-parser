import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';

import '../models/category.dart';
import '../models/channel_live.dart';
import '../models/channel_serie.dart';
import '../models/epg.dart';
import '../models/movie_detail.dart';
import '../models/serie_details.dart';
import '../models/user.dart';
import '../models/watching.dart';

import 'gateway_service.dart';
export 'playback_url_builder.dart';
export 'provider_curation_rules.dart';

part '../locale/locale.dart';
part 'auth.dart';
part 'iptv.dart';
part '../locale/favorites.dart';

final _dio = Dio(BaseOptions(
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  },
));
final locale = GetStorage();
final favoritesLocale = GetStorage("favorites");
final gatewayService = GatewayService();


