import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:get/get.dart';

import '../../../helpers/playback_wake_lock.dart';
import '../../../helpers/tv_back_navigation.dart';
import '../../../repository/api/api.dart';
import '../../../repository/models/channel_live.dart';
import '../../screens/screens.dart';
import 'multiview_channel_picker.dart';
import 'multiview_store.dart';

/// Live multiview. Layout 2 is two equal panes. Layout 4 is the 2×2 grid.
/// Hidden panes do not start a player. Down from the layout choice reaches
/// Movies, Series, Search, Favs, and History.
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

  /// Two panes can take a taller HLS rendition. Four panes stay at 480
  /// so four players do not each pull a large stream.
  int get _hlsMaxHeight => _layout == 2 ? 720 : 480;

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
  int _layout = 2;
  final FocusNode _layoutFocus2 = FocusNode(debugLabel: 'MultiviewLayout2');
  final FocusNode _layoutFocus4 = FocusNode(debugLabel: 'MultiviewLayout4');
  static const List<String> _categoryIds = [
    'movies',
    'series',
    'search',
    'favorites',
    'history',
  ];
  static const List<String> _categoryLabels = [
    'Movies',
    'Series',
    'Search',
    'Favs',
    'History',
  ];
  static const List<IconData> _categoryIcons = [
    Icons.movie_outlined,
    Icons.tv_outlined,
    Icons.search,
    Icons.favorite_border,
    Icons.history,
  ];
  final List<FocusNode> _categoryFocus = List.generate(
    _categoryIds.length,
    (i) => FocusNode(debugLabel: 'MultiviewCategory$i'),
  );
  int _categoryIndex = 0;
  bool _playersReleased = false;
  bool _pickerOpen = false;
  Timer? _holdTimer;
  bool _holdFired = false;

  @override
  void initState() {
    super.initState();
    PlaybackWakeLock.acquire(this);
    final saved = MultiviewStore.read();
    _layout = MultiviewStore.readLayout();
    for (var i = 0; i < _tiles; i++) {
      _tilesState[i].streamId = saved[i];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCatalog();
      for (var i = 0; i < _layout; i++) {
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
    PlaybackWakeLock.release(this);
    _holdTimer?.cancel();
    _layoutFocus2.dispose();
    _layoutFocus4.dispose();
    for (final node in _categoryFocus) {
      node.dispose();
    }
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

  /// Current guide title when the loaded feed has one. Never invented.
  String? _programmeFor(int index) {
    final channel = _channelFor(index);
    if (channel == null) return null;
    final epg = XmlTvRepository.instance.nowNext(
      tvgId: channel.epgChannelId?.toString(),
      channelName: channel.name,
      streamId: channel.streamId,
    );
    final title = epg?.now.title.trim() ?? '';
    if (title.isEmpty) return null;
    return title;
  }

  void _scheduleStart(int index, {Duration stagger = Duration.zero}) {
    if (index >= _layout) return;
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
    if (index >= _layout) return;
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

  Future<void> _leave({String? category}) async {
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
    Get.back(result: category);
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

  Future<void> _stopTile(int index) async {
    final tile = _tilesState[index];
    tile.startTimer?.cancel();
    tile.timeout?.cancel();
    final old = tile.controller;
    tile.generation++;
    if (old != null) _detach(old, tile);
    tile.controller = null;
    tile.starting = false;
    if (mounted) setState(() {});
    await _disposeController(old);
  }

  Future<void> _restartTile(int index) async {
    await _stopTile(index);
    if (!mounted || _playersReleased || index >= _layout) return;
    if (_tilesState[index].streamId == null) return;
    _scheduleStart(index);
  }

  void _setLayout(int next) {
    if (next != 2 && next != 4) return;
    if (next == _layout || _playersReleased) return;
    setState(() => _layout = next);
    MultiviewStore.writeLayout(next);
    if (next == 2) {
      if (_focusIndex > 1) _focusIndex = 0;
      if (_audioIndex > 1) unawaited(_setAudio(0));
      for (var i = 2; i < _tiles; i++) {
        unawaited(_stopTile(i));
      }
      for (var i = 0; i < 2; i++) {
        if (_tilesState[i].controller != null || _tilesState[i].starting) {
          unawaited(_restartTile(i));
        }
      }
    } else {
      for (var i = 0; i < 2; i++) {
        if (_tilesState[i].controller != null || _tilesState[i].starting) {
          unawaited(_restartTile(i));
        }
      }
      for (var i = 2; i < _tiles; i++) {
        final tile = _tilesState[i];
        if (tile.streamId != null && tile.controller == null && !tile.starting) {
          _scheduleStart(i, stagger: _stagger * (i - 2));
        }
      }
    }
    _focus[_focusIndex.clamp(0, next - 1)].requestFocus();
  }

  int _neighbor(int index, LogicalKeyboardKey key) {
    if (_layout == 2) {
      if (key == LogicalKeyboardKey.arrowLeft) return 0;
      if (key == LogicalKeyboardKey.arrowRight) return 1;
      return index;
    }
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
    if (key == LogicalKeyboardKey.arrowDown && _layout == 2) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _layoutFocus2.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (_layout == 4 &&
          key == LogicalKeyboardKey.arrowDown &&
          index >= 2) {
        _layoutFocus4.requestFocus();
        return KeyEventResult.handled;
      }
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
                Expanded(child: _panes()),
                const SizedBox(height: 10),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width - 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC10141C),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                      child: Row(
                        children: [
                          _layoutChip(2, _layoutFocus2),
                          const SizedBox(width: 8),
                          _layoutChip(4, _layoutFocus4),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 28,
                            color: const Color(0x33FFFFFF),
                          ),
                          const SizedBox(width: 6),
                          for (var i = 0; i < _categoryIds.length; i++)
                            Expanded(
                              child: Center(child: _categoryChip(i)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panes() {
    final top = Row(
      children: [
        Expanded(child: _tile(0)),
        const SizedBox(width: 10),
        Expanded(child: _tile(1)),
      ],
    );
    if (_layout == 2) return top;
    return Column(
      children: [
        Expanded(child: top),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(2)),
              const SizedBox(width: 10),
              Expanded(child: _tile(3)),
            ],
          ),
        ),
      ],
    );
  }

  KeyEventResult _onLayoutKey(int layout, KeyEvent event) {
    if (isTvBackKey(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyDownEvent && _isSelect(event.logicalKey)) {
      _setLayout(layout);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _layoutFocus2.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (layout == 4) {
        _categoryIndex = 0;
        _categoryFocus[0].requestFocus();
      } else {
        _layoutFocus4.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final index = _focusIndex.clamp(0, _layout - 1);
      _focusIndex = index;
      _focus[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _categoryFocus[_categoryIndex].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCategoryKey(int index, KeyEvent event) {
    if (isTvBackKey(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyDownEvent && _isSelect(event.logicalKey)) {
      unawaited(_leave(category: _categoryIds[index]));
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && index == 0) {
      _layoutFocus4.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && index > 0) {
      _categoryIndex = index - 1;
      _categoryFocus[_categoryIndex].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        index < _categoryIds.length - 1) {
      _categoryIndex = index + 1;
      _categoryFocus[_categoryIndex].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final pane = _focusIndex.clamp(0, _layout - 1);
      _focusIndex = pane;
      _focus[pane].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _categoryChip(int index) {
    return Focus(
      focusNode: _categoryFocus[index],
      onKeyEvent: (node, event) => _onCategoryKey(index, event),
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => unawaited(_leave(category: _categoryIds[index])),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: focused
                          ? const Color(0xFF3DDCFF)
                          : const Color(0x00000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    _categoryIcons[index],
                    size: 18,
                    color: focused
                        ? const Color(0xFF3DDCFF)
                        : const Color(0xFFF7F7F8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _categoryLabels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: focused
                          ? const Color(0xFF3DDCFF)
                          : const Color(0xFFF7F7F8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _layoutChip(int layout, FocusNode node) {
    final selected = _layout == layout;
    return Focus(
      focusNode: node,
      onKeyEvent: (n, event) => _onLayoutKey(layout, event),
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _setLayout(layout),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x332EE6FF)
                    : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: focused || selected
                      ? const Color(0xFF3DDCFF)
                      : const Color(0x38FFFFFF),
                  width: focused ? 2 : 1,
                ),
              ),
              child: Text(
                layout == 2 ? '2 screens' : '4 screens',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(int index) {
    final tile = _tilesState[index];
    final focused = _focus[index].hasFocus;
    final audible = _audioIndex == index;
    final title = _titleFor(index);
    final ctrl = tile.controller;
    return Focus(
      focusNode: _focus[index],
      onFocusChange: (hasFocus) {
        if (!mounted) return;
        if (hasFocus) _focusIndex = index;
        setState(() {});
      },
      onKeyEvent: (node, event) => _onTileKey(index, event),
      child: GestureDetector(
        onTap: () => _onOk(index),
        onLongPress: () {
          unawaited(_setAudio(index));
          unawaited(_openPicker(index));
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0E),
            borderRadius: BorderRadius.circular(8),
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: Color(0x883DDCFF),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focused
                  ? const Color(0xFF3DDCFF)
                  : const Color(0x22FFFFFF),
              width: focused ? 3 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
            fit: StackFit.expand,
            children: [
              if (ctrl != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final ratio = height <= 0
                        ? 16 / 9
                        : constraints.maxWidth / height;
                    return VlcPlayer(
                      key: ValueKey('multiview-$index-${tile.generation}'),
                      controller: ctrl,
                      aspectRatio: ratio,
                      placeholder: const SizedBox.shrink(),
                    );
                  },
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
              if (focused && title.isNotEmpty)
                const Positioned(
                  left: 10,
                  top: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xCC10141C),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF3DDCFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              if (focused && title.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: ListenableBuilder(
                    listenable: XmlTvRepository.instance,
                    builder: (context, _) {
                      final programme = _programmeFor(index);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xE610141C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (programme != null)
                                Text(
                                  programme,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFF7F7F8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              Text(
                                'Stream ${index + 1}  ·  $title',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFB8C4D4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (audible)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    color: Color(0xFF3DDCFF),
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
