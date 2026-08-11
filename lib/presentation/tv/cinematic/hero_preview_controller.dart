import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'cinematic_artwork.dart';
import 'cinematic_prefs.dart';
import 'cinematic_tokens.dart';

/// Exactly one browse-hero decoder. Cancelled on every focus change.
class HeroPreviewController extends ChangeNotifier {
  Timer? _trailerTimer;
  VideoPlayerController? _player;
  String? _sessionKey;
  String? displayedBackdrop;
  bool trailerVisible = false;
  bool _disposed = false;
  int _gen = 0;

  VideoPlayerController? get player => _player;

  void onFocusChanged({
    required String key,
    required CinematicArtwork art,
    required HeroPreviewMode mode,
    required bool lowPower,
  }) {
    if (_disposed) return;
    final sameItem = key == _sessionKey;
    final nextArt = art.displayBackdrop;
    final artChanged = displayedBackdrop != nextArt;

    if (sameItem && !artChanged && (art.trailer == null || trailerVisible)) {
      return;
    }

    if (!sameItem) {
      _sessionKey = key;
      _cancelTrailer();
      _trailerTimer?.cancel();
    }

    // Backdrop follows focus immediately — do not debounce still art.
    if (!sameItem || artChanged) {
      displayedBackdrop = nextArt;
      notifyListeners();
    }

    if (sameItem) return;

    final playable = art.trailer;
    if (lowPower || mode == HeroPreviewMode.off || playable == null) {
      return;
    }

    _trailerTimer = Timer(CinematicMotion.trailerDebounce, () {
      if (_disposed || _sessionKey != key) return;
      _startTrailer(
        playable,
        muted: mode != HeroPreviewMode.sound,
      );
    });
  }

  Future<void> _startTrailer(String url, {required bool muted}) async {
    final gen = ++_gen;
    VideoPlayerController? created;
    try {
      created = VideoPlayerController.networkUrl(Uri.parse(url));
      await created.setVolume(muted ? 0 : 1);
      await created.setLooping(true);
      await created.initialize();
      if (_disposed || gen != _gen) {
        await created.dispose();
        return;
      }
      await created.play();
      if (_disposed || gen != _gen) {
        await created.dispose();
        return;
      }
      _player = created;
      trailerVisible = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[HERO_PREVIEW] skip: ${e.runtimeType}');
      try {
        await created?.dispose();
      } catch (_) {}
      if (!_disposed && gen == _gen) {
        _player = null;
        trailerVisible = false;
        notifyListeners();
      }
    }
  }

  void _cancelTrailer() {
    _gen++;
    final old = _player;
    _player = null;
    trailerVisible = false;
    if (old != null) {
      scheduleMicrotask(() async {
        try {
          await old.pause();
        } catch (_) {}
        try {
          await old.dispose();
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _trailerTimer?.cancel();
    _cancelTrailer();
    super.dispose();
  }
}
