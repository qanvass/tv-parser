import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:pod_player/pod_player.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:android_tv_text_field/native_textfield_tv.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../helpers/helpers.dart';
import '../../logic/blocs/auth/auth_bloc.dart';
import '../../logic/cubits/watch/watching_cubit.dart';
import '../../repository/models/watching.dart';
import '../screens/screens.dart';

part 'appbar.dart';
part 'dialog.dart';
part 'movie.dart';
part 'user.dart';
part 'welcome.dart';
part 'watching.dart';
