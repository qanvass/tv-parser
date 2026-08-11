import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Android TV remotes send [LogicalKeyboardKey.goBack]; emulators/desktop
/// often send [LogicalKeyboardKey.escape]. Both must be treated as Back.
bool isTvBackKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack;

enum TvBackDecision {
  ignoreDuplicate,
  closePanel,
  popRoute,
}

/// Pure decision for the one-back-one-action invariant.
///
/// Same physical Back can arrive on Focus *and* PopScope. A panel-close
/// and a route pop must never both run for that single press.
TvBackDecision decideTvBack({
  required bool backInFlight,
  required bool panelOpen,
  Duration? sinceLastBack,
  Duration samePressWindow = TvBackGate.samePressWindow,
}) {
  if (backInFlight) return TvBackDecision.ignoreDuplicate;
  if (sinceLastBack != null && sinceLastBack < samePressWindow) {
    return TvBackDecision.ignoreDuplicate;
  }
  if (panelOpen) return TvBackDecision.closePanel;
  return TvBackDecision.popRoute;
}

/// Test/ADB telemetry. No credentials. [playerBackCount] increments only
/// on an actual route-exit action.
class TvBackTelemetry {
  static int playerBackCount = 0;
  static String? lastScreen;
  static String? lastSource;
  static String? lastAction;
  static String? lastRouteBefore;
  static String? lastRouteAfter;
  static bool lastBlockedDuplicate = false;

  static void reset() {
    playerBackCount = 0;
    lastScreen = null;
    lastSource = null;
    lastAction = null;
    lastRouteBefore = null;
    lastRouteAfter = null;
    lastBlockedDuplicate = false;
  }
}

void logTvBack({
  required String screen,
  required String source,
  required String action,
  required bool blockedDuplicate,
  String? routeBefore,
  String? routeAfter,
}) {
  TvBackTelemetry.lastScreen = screen;
  TvBackTelemetry.lastSource = source;
  TvBackTelemetry.lastAction = action;
  TvBackTelemetry.lastBlockedDuplicate = blockedDuplicate;
  if (!blockedDuplicate) {
    TvBackTelemetry.lastRouteBefore = routeBefore;
    TvBackTelemetry.lastRouteAfter = routeAfter;
  }
  if (action == 'popRoute' && !blockedDuplicate) {
    TvBackTelemetry.playerBackCount += 1;
  }
  debugPrint(
    '[TV_BACK] screen=$screen source=$source action=$action '
    'blockedDuplicate=$blockedDuplicate '
    'playerBackCount=${TvBackTelemetry.playerBackCount} '
    'routeBefore=${routeBefore ?? '-'} '
    'routeAfter=${routeAfter ?? '-'}',
  );
}

/// Per-screen re-entrancy + same-press debounce.
///
/// Do not reset [backInFlight] before the route is disposed.
class TvBackGate {
  TvBackGate({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const Duration samePressWindow = Duration(milliseconds: 300);
  static const Duration shellExitSuppressWindow = Duration(milliseconds: 400);

  static DateTime? _suppressShellExitUntil;

  /// Call when any child route commits a pop so a leftover Back cannot
  /// immediately finish the shell / Activity.
  static void noteRoutePopped() {
    _suppressShellExitUntil = DateTime.now().add(shellExitSuppressWindow);
  }

  static bool shouldSuppressShellExit([DateTime? now]) {
    final until = _suppressShellExitUntil;
    if (until == null) return false;
    return (now ?? DateTime.now()).isBefore(until);
  }

  @visibleForTesting
  static void resetShellSuppress() {
    _suppressShellExitUntil = null;
  }

  final DateTime Function() _now;
  bool _backInFlight = false;
  DateTime? _lastHandledAt;

  bool get backInFlight => _backInFlight;

  Duration? get sinceLastBack {
    final last = _lastHandledAt;
    if (last == null) return null;
    return _now().difference(last);
  }

  /// Returns false if this Back is a duplicate of an in-flight exit or the
  /// same physical press already handled by Focus or PopScope.
  bool allow({required String screen, required String source}) {
    if (_backInFlight) {
      logTvBack(
        screen: screen,
        source: source,
        action: 'blockedDuplicate',
        blockedDuplicate: true,
        routeBefore: _safeRoute(),
      );
      return false;
    }
    final last = _lastHandledAt;
    if (last != null && _now().difference(last) < samePressWindow) {
      logTvBack(
        screen: screen,
        source: source,
        action: 'blockedDuplicate',
        blockedDuplicate: true,
        routeBefore: _safeRoute(),
      );
      return false;
    }
    _lastHandledAt = _now();
    return true;
  }

  void markRouteExit() {
    _backInFlight = true;
    noteRoutePopped();
  }

  static String _safeRoute() {
    try {
      return Get.currentRoute;
    } catch (_) {
      return '-';
    }
  }
}
