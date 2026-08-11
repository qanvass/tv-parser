/// Coordinates Welcome cosmetic overlay vs Live hero preview.
///
/// Preview must not start while the Hold-please card is up: on Chromecast,
/// VLC play() can block the UI thread so overlay dismiss never paints.
abstract final class LiveBrowseGate {
  static bool welcomeOverlayCleared = false;

  static final List<void Function()> _waiters = <void Function()>[];

  static void markWelcomeCleared() {
    if (welcomeOverlayCleared) return;
    welcomeOverlayCleared = true;
    final pending = List<void Function()>.from(_waiters);
    _waiters.clear();
    for (final w in pending) {
      w();
    }
  }

  /// Runs [action] now if overlay is gone; otherwise when it clears (or
  /// after [fallback] wall-clock, whichever first).
  static void whenBrowseReady(
    void Function() action, {
    Duration fallback = const Duration(seconds: 4),
  }) {
    if (welcomeOverlayCleared) {
      action();
      return;
    }
    var ran = false;
    void runOnce() {
      if (ran) return;
      ran = true;
      action();
    }

    _waiters.add(runOnce);
    Future<void>.delayed(fallback, () {
      markWelcomeCleared();
      runOnce();
    });
  }
}
