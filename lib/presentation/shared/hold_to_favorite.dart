import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A remote OK press opens on release; a hold saves without opening playback.
mixin HoldToFavorite<T extends StatefulWidget> on State<T> {
  Timer? _holdTimer;
  LogicalKeyboardKey? _heldKey;
  FocusNode? _heldFocus;
  bool _savedOnHold = false;

  KeyEventResult favoriteKey(KeyEvent event, {
    required VoidCallback onOpen,
    required VoidCallback onFavorite,
  }) {
    final key = event.logicalKey;
    final activate = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space;
    if (!activate) {
      if (event is KeyDownEvent) cancelFavoriteHold();
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && _heldKey == null) {
      _heldKey = key;
      _savedOnHold = false;
      _heldFocus = FocusManager.instance.primaryFocus;
      _heldFocus?.addListener(_checkFavoriteFocus);
      _holdTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted || _heldKey == null) return;
        _savedOnHold = true;
        onFavorite();
      });
    } else if (event is KeyUpEvent && _heldKey == key) {
      final open = !_savedOnHold;
      cancelFavoriteHold();
      if (open) onOpen();
    }
    return KeyEventResult.handled;
  }

  void _checkFavoriteFocus() {
    if (_heldFocus?.hasPrimaryFocus != true) cancelFavoriteHold();
  }

  void cancelFavoriteHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _heldFocus?.removeListener(_checkFavoriteFocus);
    _heldFocus = null;
    _heldKey = null;
    _savedOnHold = false;
  }

  @override
  void dispose() {
    cancelFavoriteHold();
    super.dispose();
  }
}
