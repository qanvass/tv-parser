import 'package:flutter/cupertino.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:mbark_iptv/repository/api/saved_accounts_service.dart';
import 'package:mbark_iptv/repository/models/user.dart';

import '../../../helpers/helpers.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthApi authApi;

  AuthBloc(this.authApi) : super(AuthInitial()) {
    on<AuthRegister>((event, emit) async {
      emit(AuthLoading());

      final user = await authApi.registerUser(
        event.username,
        event.password,
        event.domain,
        "test",
      );

      if (user != null) {
        final status = user.userInfo?.status?.trim().toLowerCase();
        if (status == 'active') {
          await SavedAccountsService.upsertXtream(
            username: event.username,
            password: event.password,
            domain: event.domain,
          );
          changeDeviceOrient();
          await Future.delayed(const Duration(milliseconds: 300));
          emit(AuthSuccess(user));
        } else {
          emit(
            AuthFailed(
              "Account is inactive or expired. Status: ${user.userInfo?.status ?? 'Unknown'}",
            ),
          );
        }
      } else {
        emit(AuthFailed("could not login!!"));
      }
    });

    on<AuthGetUser>((event, emit) async {
      emit(AuthLoading());

      final localeUser = await LocaleApi.getUser();

      if (localeUser != null) {
        final status = localeUser.userInfo?.status?.trim().toLowerCase();
        if (status == 'active') {
          changeDeviceOrient();
          emit(AuthSuccess(localeUser));
        } else {
          await LocaleApi.logOut();
          emit(AuthFailed("Account is inactive or expired."));
        }
      } else {
        emit(AuthFailed("could not login!!"));
      }
    });

    on<AuthLogOut>((event, emit) async {
      await LocaleApi.logOut();
      changeDeviceOrientBack();
      emit(AuthFailed("LogOut"));
    });

    on<AuthLoadM3u>((event, emit) async {
      emit(AuthLoading());

      final user = await authApi.registerM3u(event.playlistUrl);

      if (user != null) {
        await SavedAccountsService.upsertM3u(playlistUrl: event.playlistUrl);
        changeDeviceOrient();
        await Future.delayed(const Duration(milliseconds: 300));
        emit(AuthSuccess(user));
      } else {
        emit(
          AuthFailed(
            "Could not parse or load M3U playlist. Make sure the URL is valid.",
          ),
        );
      }
    });
  }
}
