import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:get/get.dart';

import '../../../helpers/tv_back_navigation.dart';
import '../../../repository/api/api.dart';
import '../../../repository/models/channel_live.dart';
import '../../screens/screens.dart';
import 'multiview_channel_picker.dart';
import 'multiview_store.dart';

/// 2×2 live grid. Each tile has its own [VlcPlayerController].
///
/// D-pad moves the ring. OK makes that tile the only one with audio.
/// OK again, or holding OK, opens the live channel list for that tile.
/// Back releases every player and returns to the dashboard.
class MultiviewScreen extends StatefulWidget {
  const MultiviewScreen({super.key});

  @override
  State<MultiviewScreen> createState() => _MultiviewScreenState();
}

class _Tile {
  String? streamId;
  VlcPlayerController? controller;
  VoidCallback? onInit;
  VoidCallback? onValue;
  int generation = 0;
  int attempts = 0;
  String? error;
  bool starting = false;
  Timer? startTimer;
  Timer? timeout;
}

class _MultiviewScreenState extends State<MultiviewScreen> {
  static const int _tiles = MultiviewStore.slotCount;
  static const Duration _stagger = Duration(milliseconds: 400);
  static const int _hlsMaxHeight = 480;

  final List<_Tile> _tilesState = List.generate(_tiles, (_) => _Tile());
  final List<FocusNode> _focus = List.generate(
    _tiles,
    (i) => FocusNode(debugLabel: 'MultiviewTile$i'),
  );
  final TvBackGate _backGate = TvBackGate();

  Map<String, ChannelLive> _byId = const {};
  Set<String> _hiddenCategoryIds = const {};
  int _focusIndex = 0;
  int _audioIndex = 0;
  bool _playersReleased = false;
  bool _pickerOpen = false;
  Timer? _holdTimer;
  bool _holdFired = false;

  @override
  void initState() {
    super.initState();
    final saved = MultiviewStore.read();
    for (var i = 0; i < _tiles; i++) {
      _tilesState[i].streamId = saved[i];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCatalog();
      for (var i = 0; i < _tiles; i++) {
        if (_tilesState[i].streamId != null) {
          _scheduleStart(i, stagger: _stagger * i);
        }
      }
      _focus[0].requestFocus();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    for (final node in _focus) {
      node.dispose();
    }
    if (!_playersReleased) {
      for (final tile in _tilesState) {
        tile.startTimer?.cancel();
        tile.timeout?.cancel();
        final ctrl = tile.controller;
        if (ctrl != null) _detach(ctrl, tile);
        tile.controller = null;
        unawaited(_disposeController(ctrl));
      }
      _playersReleased = true;
    }
    super.dispose();
  }

  void _loadCatalog() {
    final session = IptvProviderSession.instance;
    final hidden = <String>{};
    for (final cat in session.categoriesForAction('get_live_categories')) {
      final name = cat.categoryName;
      final id = cat.categoryId;
      if (name != null &&
          id != null &&
          id.isNotEmpty &&
          ProviderCurationRules.isAdultCategory(name)) {
        hidden.add(id);
      }
    }
    final byId = <String, ChannelLive>{};
    for (final ch in session.liveChannels()) {
      final id = ch.streamId?.trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = ch;
    }
    _hiddenCategoryIds = hidden;
    _byId = byId;
  }

  bool _isHidden(ChannelLive channel) {
    final catId = channel.categoryId;
    if (catId != null && _hiddenCategoryIds.contains(catId)) return true;
    final flag = (channel.isAdult ?? '').toLowerCase();
    return flag == '1' || flag == 'true';
  }

  ChannelLive? _channelFor(int index) {
    final id = _tilesState[index].streamId;
    if (id == null) return null;
    final channel = _byId[id];
    if (channel == null || _isHidden(channel)) return null;
    return channel;
  }

  String _titleFor(int index) {
    final channel = _channelFor(index);
    final name = channel?.name?.trim() ?? '';
    if (name.isNotEmpty) return name;
    if (_tilesState[index].streamId != null) return 'Saved channel';
    return '';
  }

  void _scheduleStart(int index, {Duration stagger = Duration.zero}) {
    final tile = _tilesState[index];
    tile.startTimer?.cancel();
    final generation = tile.generation;
    tile.starting = tile.streamId != null;
    tile.startTimer = Timer(stagger, () {
      unawaited(_startTile(index, generation));
    });
  }

  Future<void> _startTile(int index, int generation) async {
    final tile = _tilesState[index];
    if (!mounted || tile.generation != generation || _playersReleased) return;
    final channel = _channelFor(index);
    if (channel == null) {
      if (!mounted || tile.generation != generation) return;
      setState(() {
        tile.starting = false;
        tile.error = tile.streamId == null
            ? null
            : 'This channel is not in the current list';
      });
      return;
    }
    final url = IptvProviderSession.instance.resolveLiveUrl(channel);
    if (!mounted || tile.generation != generation || _playersReleased) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _failTile(
        index,
        generation,
        'This channel has no playable address',
        retry: false,
      );
      return;
    }

    late final VlcPlayerController created;
    try {
      created = VlcPlayerController.network(
        url,
        hwAcc: HwAcc.auto,
        autoPlay: false,
        options: buildVlcPlaybackOptions(
          isLive: true,
          streamUrl: url,
          adaptiveMaxHeight: _hlsMaxHeight,
        ),
      );
    } catch (_) {
      _failTile(index, generation, 'Could not open this channel', retry: true);
      return;
    }
    if (!mounted || tile.generation != generation || _playersReleased) {
      unawaited(_disposeController(created));
      return;
    }

    void onInit() {
      unawaited(_afterInit(index, generation, created));
    }

    void onValue() {
      if (!mounted || tile.generation != generation) return;
      if (tile.controller != created) return;
      final value = created.value;
        if (value.hasError || value.playingState == PlayingState.error) {
          scheduleMicrotask(() {
            unawaited(
              _failTile(
                index,
                generation,
                'This channel stopped',
                retry: true,
              ),
            );
          });
        }
    }

    created.addOnInitListener(onInit);
    created.addListener(onValue);
    tile.onInit = onInit;
    tile.onValue = onValue;
    tile.controller = created;
    tile.error = null;
    tile.starting = true;
    tile.timeout?.cancel();
    tile.timeout = Timer(const Duration(seconds: 18), () {
      if (!mounted || tile.generation != generation) return;
      if (tile.controller != created) return;
      final value = created.value;
      if (value.isInitialized && !value.hasError) return;
      unawaited(
        _failTile(
          index,
          generation,
          'This channel did not start',
          retry: true,
        ),
      );
    });
    if (mounted) setState(() {});
  }

  Future<void> _afterInit(
    int index,
    int generation,
    VlcPlayerController ctrl,
  ) async {
    final tile = _tilesState[index];
    if (!mounted || tile.generation != generation || tile.controller != ctrl) {
      return;
    }
    tile.timeout?.cancel();
    final audible = index == _audioIndex;
    try {
      await ctrl.setVolume(audible ? 100 : 0);
    } catch (_) {
      if (!audible) {
        await _failTile(
          index,
          generation,
          'This tile stayed silent',
          retry: false,
        );
        return;
      }
    }
    if (!mounted || tile.generation != generation || tile.controller != ctrl) {
      return;
    }
    try {
      await ctrl.play();
    } catch (_) {
      await _failTile(
        index,
        generation,
        'This channel did not start',
        retry: true,
      );
      return;
    }
    if (!mounted || tile.generation != generation) return;
    setState(() {
      tile.starting = false;
      tile.error = null;
    });
  }

  Future<void> _failTile(
    int index,
    int generation,
    String message, {
    required bool retry,
  }) async {
    final tile = _tilesState[index];
    if (!mounted || tile.generation != generation || _playersReleased) return;
    final old = tile.controller;
    tile.generation = generation + 1;
    tile.timeout?.cancel();
    tile.startTimer?.cancel();
    if (old != null) _detach(old, tile);
    tile.controller = null;
    tile.starting = false;
    debugPrint('[MULTIVIEW] tile=$index stopped');
    if (mounted) setState(() {});
    await _disposeController(old);
    if (!mounted || _playersReleased || tile.generation != generation + 1) {
      return;
    }
    if (retry && tile.attempts < 1) {
      tile.attempts += 1;
      tile.error = message;
      tile.startTimer?.cancel();
      tile.startTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || _playersReleased) return;
        if (tile.generation != generation + 1) return;
        tile.error = null;
        tile.starting = true;
        setState(() {});
        _scheduleStart(index, stagger: Duration.zero);
      });
      if (mounted) setState(() {});
      return;
    }
    tile.error = message;
    if (mounted) setState(() {});
  }

  void _detach(VlcPlayerController ctrl, _Tile tile) {
    final onValue = tile.onValue;
    final onInit = tile.onInit;
    tile.onValue = null;
    tile.onInit = null;
    if (onValue != null) {
      try {
        ctrl.removeListener(onValue);
      } catch (_) {}
    }
    if (onInit != null) {
      try {
        ctrl.removeOnInitListener(onInit);
      } catch (_) {}
    }
  }

  Future<void> _disposeController(VlcPlayerController? ctrl) async {
    if (ctrl == null) return;
    // Let the VlcPlayer widget leave the tree before native dispose.
    await Future<void>.delayed(Duration.zero);
    try {
      if (ctrl.value.isInitialized) await ctrl.setVolume(0);
    } catch (_) {}
    try {
      if (ctrl.value.isInitialized) await ctrl.stop();
    } catch (_) {}
    try {
      await ctrl.stopRendererScanning();
    } catch (_) {}
    try {
      await ctrl.dispose();
    } catch (_) {}
  }

  Future<void> _releaseAll() async {
    if (_playersReleased) return;
    _playersReleased = true;
    _holdTimer?.cancel();
    final pending = <VlcPlayerController>[];
    for (final tile in _tilesState) {
      tile.startTimer?.cancel();
      tile.timeout?.cancel();
      tile.generation++;
      final ctrl = tile.controller;
      if (ctrl != null) {
        _detach(ctrl, tile);
        pending.add(ctrl);
      }
      tile.controller = null;
      tile.starting = false;
    }
    if (mounted) setState(() {});
    await Future<void>.delayed(Duration.zero);
    await Future.wait(pending.map(_disposeController));
  }

  Future<void> _leave() async {
    if (!mounted || _pickerOpen) return;
    if (!_backGate.allow(screen: 'MultiviewScreen', source: 'focus')) return;
    _backGate.markRouteExit();
    logTvBack(
      screen: 'MultiviewScreen',
      source: 'focus',
      action: 'popRoute',
      blockedDuplicate: false,
      routeBefore: Get.currentRoute,
    );
    await _releaseAll();
    if (!mounted) return;
    Get.back();
  }

  Future<void> _setAudio(int index) async {
    if (_audioIndex == index) return;
    final previous = _audioIndex;
    _audioIndex = index;
    if (mounted) setState(() {});
    await _applyVolume(previous);
    await _applyVolume(index);
  }

  Future<void> _applyVolume(int index) async {
    final tile = _tilesState[index];
    final ctrl = tile.controller;
    if (ctrl == null) return;
    final generation = tile.generation;
    final audible = index == _audioIndex;
    try {
      if (!ctrl.value.isInitialized) return;
      await ctrl.setVolume(audible ? 100 : 0);
    } catch (_) {
      if (!audible) {
        await _failTile(
          index,
          generation,
          'This tile stayed silent',
          retry: false,
        );
      }
    }
  }

  bool _canHear(int index) {
    final tile = _tilesState[index];
    return tile.streamId != null &&
        tile.error == null &&
        _channelFor(index) != null;
  }

  void _onOk(int index) {
    _focusIndex = index;
    if (!_canHear(index)) {
      unawaited(_setAudio(index));
      unawaited(_openPicker(index));
      return;
    }
    if (_audioIndex != index) {
      unawaited(_setAudio(index));
      return;
    }
    unawaited(_openPicker(index));
  }

  Future<void> _openPicker(int index) async {
    if (!mounted || _pickerOpen || _playersReleased) return;
    _pickerOpen = true;
    final picked = await Navigator.of(context).push<ChannelLive>(
      MaterialPageRoute(builder: (_) => const MultiviewChannelPicker()),
    );
    _pickerOpen = false;
    if (!mounted || _playersReleased) return;
    _focus[index].requestFocus();
    if (picked == null) {
      setState(() {});
      return;
    }
    await _assign(index, picked);
  }

  Future<void> _assign(int index, ChannelLive channel) async {
    final id = channel.streamId?.trim() ?? '';
    if (id.isEmpty || !mounted || _playersReleased) return;
    final tile = _tilesState[index];
    tile.startTimer?.cancel();
    tile.timeout?.cancel();
    final old = tile.controller;
    tile.generation++;
    if (old != null) _detach(old, tile);
    tile.controller = null;
    tile.streamId = id;
    tile.attempts = 0;
    tile.error = null;
    tile.starting = true;
    _byId[id] = channel;
    MultiviewStore.write(_tilesState.map((t) => t.streamId).toList());
    if (mounted) setState(() {});
    final generation = tile.generation;
    unawaited(_startAfterDispose(index, generation, old));
  }

  Future<void> _startAfterDispose(
    int index,
    int generation,
    VlcPlayerController? old,
  ) async {
    await _disposeController(old);
    if (!mounted || _playersReleased) return;
    if (_tilesState[index].generation != generation) return;
    _scheduleStart(index);
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.numpadEnter;

  int _neighbor(int index, LogicalKeyboardKey key) {
    final col = index % 2;
    final row = index ~/ 2;
    if (key == LogicalKeyboardKey.arrowLeft) {
      return row * 2 + (col == 0 ? 0 : col - 1);
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return row * 2 + (col == 1 ? 1 : col + 1);
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return row == 0 ? index : index - 2;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return row == 1 ? index : index + 2;
    }
    return index;
  }

  KeyEventResult _onTileKey(int index, KeyEvent event) {
    if (isTvBackKey(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyUpEvent && _isSelect(event.logicalKey)) {
      _holdTimer?.cancel();
      _holdTimer = null;
      if (_holdFired) {
        _holdFired = false;
        return KeyEventResult.handled;
      }
      _onOk(index);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && _isSelect(event.logicalKey)) {
      _holdFired = false;
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: 500), () {
        _holdFired = true;
        _holdTimer = null;
        unawaited(_setAudio(index));
        unawaited(_openPicker(index));
      });
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent && _isSelect(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      final next = _neighbor(index, key);
      if (next != index) {
        _focusIndex = next;
        _focus[next].requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onScreenKey(FocusNode _, KeyEvent event) {
    if (!isTvBackKey(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      if (_backGate.backInFlight || TvBackGate.shouldSuppressShellExit()) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    unawaited(_leave());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onScreenKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF050A18),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _tile(0)),
                      const SizedBox(width: 8),
                      Expanded(child: _tile(1)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _tile(2)),
                      const SizedBox(width: 8),
                      Expanded(child: _tile(3)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'OK listens on this tile. OK again changes the channel. Back closes.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFB8B8C0),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(int index) {
    final tile = _tilesState[index];
    final focused = _focus[index].hasFocus || _focusIndex == index;
    final audible = _audioIndex == index;
    final title = _titleFor(index);
    final ctrl = tile.controller;
    return Focus(
      focusNode: _focus[index],
      onFocusChange: (hasFocus) {
        if (hasFocus && _focusIndex != index && mounted) {
          setState(() => _focusIndex = index);
        }
      },
      onKeyEvent: (node, event) => _onTileKey(index, event),
      child: GestureDetector(
        onTap: () => _onOk(index),
        onLongPress: () {
          unawaited(_setAudio(index));
          unawaited(_openPicker(index));
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0E),
            border: Border.all(
              color: focused ? Colors.white : const Color(0x33FFFFFF),
              width: focused ? 3 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ctrl != null)
                Center(
                  child: VlcPlayer(
                    key: ValueKey('multiview-$index-${tile.generation}'),
                    controller: ctrl,
                    aspectRatio: 16 / 9,
                    placeholder: const SizedBox.shrink(),
                  ),
                ),
              if (tile.starting)
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xCCF2F2F5),
                  ),
                ),
              if (ctrl == null && !tile.starting)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tile.error ?? 'Add a channel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF7F7F8),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFFB8B8C0),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Empty' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (audible)
                      const Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
