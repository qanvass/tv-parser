part of '../screens.dart';

// ─── LIVE TV — 3-PANEL SCREEN ─────────────────────────────────────────────────
// Layout:  [Categories]  |  [Channels]  |  [Player + EPG]
//
// FULLSCREEN STRATEGY: The VlcPlayer widget is ALWAYS kept at the same
// position in the widget tree (Expanded at index 4 of the Row). When going
// fullscreen, the side panels and appbar are collapsed with AnimatedAlign
// (widthFactor/heightFactor → 0) + ClipRect. A controls-only overlay is then
// placed on top. This prevents the "Already Initialized" crash caused by
// VlcPlayer being disposed and recreated.

const double _kItemH = 52.0;
const Duration _kPanelAnim = Duration(milliseconds: 280);
const Curve _kPanelCurve = Curves.easeInOut;

class LiveCategoriesScreen extends StatefulWidget {
  const LiveCategoriesScreen({super.key});

  @override
  State<LiveCategoriesScreen> createState() => _LiveCategoriesScreenState();
}

class _LiveCategoriesScreenState extends State<LiveCategoriesScreen> {
  // ── Categories ────────────────────────────────────────────────────────────
  List<CategoryModel> _cats = [];
  int _catIdx = 0;

  // ── Channels ──────────────────────────────────────────────────────────────
  List<ChannelLive> _chs = [];
  int _chIdx = 0;
  ChannelLive? _selCh;
  String _chSearch = '';
  bool _chLoading = false;

  // ── Player ────────────────────────────────────────────────────────────────
  VlcPlayerController? _player;
  bool _isFullscreen = false;

  // ── D-pad panel focus (0 = categories, 1 = channels) ─────────────────────
  int _panel = 0;

  // ── Scroll / focus ────────────────────────────────────────────────────────
  final _catScroll = ScrollController();
  final _chScroll = ScrollController();
  final _navFocus = FocusNode();

  // ── Search (appbar) ───────────────────────────────────────────────────────
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChange);
    final s = context.read<LiveCatyBloc>().state;
    if (s is LiveCatySuccess && s.categories.isNotEmpty) {
      _initCats(s.categories);
    }
  }

  void _onSearchFocusChange() {
    if (!_searchFocus.hasFocus && mounted) {
      setState(() => _showSearch = false);
      _navFocus.requestFocus();
    }
  }

  void _initCats(List<CategoryModel> cats) {
    if (_cats.isNotEmpty) return;
    _cats = cats;
    _fetchChannels(cats[0].categoryId ?? '');
  }

  void _fetchChannels(String catyId) {
    setState(() {
      _chs = [];
      _chIdx = 0;
      _chLoading = true;
    });
    context.read<ChannelsBloc>().add(
      GetLiveChannelsEvent(catyId: catyId, typeCategory: TypeCategory.live),
    );
  }

  Future<void> _play(ChannelLive ch, int idx) async {
    final user = await LocaleApi.getUser();
    final url =
        '${user!.serverInfo!.serverUrl}/${user.userInfo!.username}/${user.userInfo!.password}/${ch.streamId}';

    try {
      _player?.pause();
      _player?.stop();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 200));

    final ctrl = VlcPlayerController.network(
      url,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
          VlcAdvancedOptions.liveCaching(2000),
        ]),
      ),
    );

    if (mounted) {
      setState(() {
        _player = ctrl;
        _selCh = ch;
        _chIdx = idx;
      });
    }
  }

  // Toggle fullscreen WITHOUT recreating the VlcPlayer.
  // Side panels are collapsed via AnimatedAlign, so VlcPlayer stays at the
  // same tree position and is never disposed/recreated.
  void _toggleFullscreen() {
    final going = !_isFullscreen;
    if (going) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    setState(() => _isFullscreen = going);
  }

  @override
  void deactivate() {
    // Restore system UI when leaving screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try {
      _player?.pause();
      _player?.stop();
    } catch (_) {}
    super.deactivate();
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChange);
    _catScroll.dispose();
    _chScroll.dispose();
    _navFocus.dispose();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    if (_player != null) {
      _player!.stopRendererScanning().catchError((_) {});
      _player!.dispose();
    }
    super.dispose();
  }

  // ── D-pad ─────────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (_searchFocus.hasFocus) return KeyEventResult.ignored;
    if (_isFullscreen) return KeyEventResult.ignored; // overlay handles it
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_panel > 0) setState(() => _panel--);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_panel < 1) setState(() => _panel++);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _dpadUp();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _dpadDown();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      _dpadSelect();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _dpadUp() {
    if (_panel == 0) {
      if (_catIdx > 0) {
        setState(() => _catIdx--);
        _scrollTo(_catScroll, _catIdx);
      }
    } else {
      if (_chIdx > 0) {
        setState(() => _chIdx--);
        _scrollTo(_chScroll, _chIdx);
      }
    }
  }

  void _dpadDown() {
    if (_panel == 0) {
      if (_catIdx < _cats.length - 1) {
        setState(() => _catIdx++);
        _scrollTo(_catScroll, _catIdx);
      }
    } else {
      if (_chIdx < _filteredChs.length - 1) {
        setState(() => _chIdx++);
        _scrollTo(_chScroll, _chIdx);
      }
    }
  }

  void _dpadSelect() {
    if (_panel == 0 && _cats.isNotEmpty) {
      _fetchChannels(_cats[_catIdx].categoryId ?? '');
    } else if (_panel == 1 && _filteredChs.isNotEmpty) {
      final ch = _filteredChs[_chIdx];
      if (_selCh != null && _selCh!.streamId == ch.streamId) {
        _toggleFullscreen();
      } else {
        _play(ch, _chIdx);
      }
    }
  }

  void _scrollTo(ScrollController sc, int idx) {
    if (!sc.hasClients) return;
    final target = (idx * (_kItemH + 4)).clamp(
      0.0,
      sc.position.maxScrollExtent,
    );
    sc.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  List<ChannelLive> get _filteredChs {
    if (_chSearch.isEmpty) return _chs;
    return _chs
        .where((c) => (c.name ?? '').toLowerCase().contains(_chSearch))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleFullscreen();
      },
      child: BlocListener<LiveCatyBloc, LiveCatyState>(
        listener: (_, s) {
          if (s is LiveCatySuccess) _initCats(s.categories);
        },
        child: BlocListener<ChannelsBloc, ChannelsState>(
          listener: (_, s) {
            if (s is ChannelsLiveSuccess && mounted) {
              setState(() {
                _chs = s.channels;
                _chLoading = false;
                _chIdx = 0;
                _panel = 1;
              });
              if (_chScroll.hasClients) _chScroll.jumpTo(0);
            }
          },
          child: Focus(
            focusNode: _navFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Main layout (VlcPlayer always at fixed tree position) ──
                  Ink(
                    decoration: _isFullscreen
                        ? const BoxDecoration(color: Colors.black)
                        : kDecorBackground,
                    child: Column(
                      children: [
                        // App bar — collapses to height 0 when fullscreen
                        ClipRect(
                          child: AnimatedAlign(
                            alignment: Alignment.topCenter,
                            heightFactor: _isFullscreen ? 0.0 : 1.0,
                            duration: _kPanelAnim,
                            curve: _kPanelCurve,
                            child: SafeArea(
                              bottom: false,
                              child: SizedBox(height: 56, child: _buildBar()),
                            ),
                          ),
                        ),

                        // Panels row
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Categories panel — collapses to width 0
                              _collapseH(
                                width: 210,
                                collapsed: _isFullscreen,
                                child: _LivePanel(
                                  label: 'CATEGORIES',
                                  isLoading: _cats.isEmpty,
                                  scroll: _catScroll,
                                  itemCount: _cats.length,
                                  itemBuilder: (i) => _LivePanelItem(
                                    icon: FontAwesomeIcons.list,
                                    label: _cats[i].categoryName ?? '',
                                    isSelected: i == _catIdx,
                                    isHighlighted: i == _catIdx && _panel == 0,
                                    onTap: () {
                                      setState(() => _catIdx = i);
                                      _fetchChannels(_cats[i].categoryId ?? '');
                                    },
                                  ),
                                ),
                              ),
                              _collapseDivider(_isFullscreen),

                              // Channels panel — collapses to width 0
                              _collapseH(
                                width: 260,
                                collapsed: _isFullscreen,
                                child: _LivePanel(
                                  label: _cats.isNotEmpty
                                      ? (_cats[_catIdx].categoryName ?? '')
                                            .toUpperCase()
                                      : 'CHANNELS',
                                  isLoading: _chLoading,
                                  scroll: _chScroll,
                                  itemCount: _filteredChs.length,
                                  emptyLabel: 'No channels',
                                  itemBuilder: (i) {
                                    final ch = _filteredChs[i];
                                    return _LivePanelItem(
                                      iconWidget:
                                          (ch.streamIcon != null &&
                                              ch.streamIcon!.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: ch.streamIcon!,
                                              width: 22,
                                              height: 22,
                                              fit: BoxFit.contain,
                                              errorWidget: (_, __, ___) => Icon(
                                                i == _chIdx
                                                    ? FontAwesomeIcons.play
                                                    : FontAwesomeIcons.tv,
                                                size: 13,
                                                color: i == _chIdx
                                                    ? kColorPrimary
                                                    : Colors.white38,
                                              ),
                                            )
                                          : null,
                                      icon: i == _chIdx
                                          ? FontAwesomeIcons.play
                                          : FontAwesomeIcons.tv,
                                      label: ch.name ?? '',
                                      isSelected: i == _chIdx,
                                      isHighlighted: i == _chIdx && _panel == 1,
                                      onTap: () {
                                        if (_selCh != null &&
                                            _selCh!.streamId == ch.streamId) {
                                          _toggleFullscreen();
                                        } else {
                                          _play(ch, i);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              _collapseDivider(_isFullscreen),

                              // ── Player — ALWAYS at tree position index 4.
                              // Never removed → VlcPlayer never recreated.
                              Expanded(
                                child: _PlayerPanel(
                                  channel: _selCh,
                                  player: _player,
                                  isFullscreen: _isFullscreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Fullscreen controls overlay (controls only, no VlcPlayer)
                  if (_isFullscreen && _player != null && _selCh != null)
                    _LiveFullscreenControls(
                      controller: _player!,
                      channel: _selCh!,
                      onClose: _toggleFullscreen,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Collapses a fixed-width panel to 0 using AnimatedAlign + ClipRect.
  Widget _collapseH({
    required double width,
    required bool collapsed,
    required Widget child,
  }) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.centerLeft,
        widthFactor: collapsed ? 0.0 : 1.0,
        duration: _kPanelAnim,
        curve: _kPanelCurve,
        child: SizedBox(width: width, child: child),
      ),
    );
  }

  Widget _collapseDivider(bool collapsed) {
    return ClipRect(
      child: AnimatedAlign(
        widthFactor: collapsed ? 0.0 : 1.0,
        duration: _kPanelAnim,
        curve: _kPanelCurve,
        alignment: Alignment.center,
        child: Container(width: 1, color: kColorCardLight),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Image(width: 32, height: 32, image: AssetImage(kIconSplash)),
          const SizedBox(width: 8),
          if (!_showSearch) ...[
            Text(kAppName, style: Get.textTheme.titleMedium),
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: kColorHint,
            ),
            const Image(height: 24, image: AssetImage(kIconLive)),
            const Spacer(),
          ] else ...[
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                onChanged: (v) => setState(() => _chSearch = v.toLowerCase()),
                style: Get.textTheme.bodyMedium!.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  hintStyle: Get.textTheme.bodyMedium!.copyWith(
                    color: kColorHint,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _chSearch = '';
                  _showSearch = false;
                });
                _navFocus.requestFocus();
              },
              icon: const Icon(
                FontAwesomeIcons.xmark,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          if (!_showSearch) ...[
            IconButton(
              focusColor: kColorFocus,
              onPressed: () => setState(() => _showSearch = true),
              icon: const Icon(
                FontAwesomeIcons.magnifyingGlass,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (_selCh != null)
              BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, state) {
                  final liked = state.lives.any(
                    (l) => l.streamId == _selCh!.streamId,
                  );
                  return IconButton(
                    focusColor: kColorFocus,
                    onPressed: () => context.read<FavoritesCubit>().addLive(
                      _selCh,
                      isAdd: !liked,
                    ),
                    icon: Icon(
                      liked
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.heart,
                      color: liked ? kColorPrimary : Colors.white,
                      size: 16,
                    ),
                  );
                },
              ),
            IconButton(
              focusColor: kColorFocus,
              onPressed: () => Get.back(),
              icon: const Icon(
                FontAwesomeIcons.chevronLeft,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Collapsing Panel Container ───────────────────────────────────────────────

class _LivePanel extends StatelessWidget {
  const _LivePanel({
    required this.label,
    required this.isLoading,
    required this.scroll,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyLabel = '',
  });

  final String label;
  final bool isLoading;
  final ScrollController scroll;
  final int itemCount;
  final Widget Function(int) itemBuilder;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Get.textTheme.bodySmall!.copyWith(
              color: kColorHint,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: kColorPrimary),
                )
              : itemCount == 0
              ? Center(
                  child: Text(
                    emptyLabel,
                    style: Get.textTheme.bodySmall!.copyWith(color: kColorHint),
                  ),
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: itemCount,
                  itemBuilder: (_, i) => itemBuilder(i),
                ),
        ),
      ],
    );
  }
}

// ─── Shared Panel Item ────────────────────────────────────────────────────────

class _LivePanelItem extends StatelessWidget {
  const _LivePanelItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
    this.iconWidget,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: _kItemH,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? kColorPrimary.withValues(alpha: .18)
              : kColorCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? kColorFocus
                : isSelected
                ? kColorPrimary.withValues(alpha: .5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .25),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child:
                  iconWidget ??
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected ? kColorPrimary : Colors.white38,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Get.textTheme.bodySmall!.copyWith(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: kColorFocus,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Player + EPG Panel ───────────────────────────────────────────────────────
// IMPORTANT: StreamPlayerPage (which contains VlcPlayer) is ALWAYS at index 0
// of the Stack so Flutter never disposes/recreates it — avoiding "Already
// Initialized". The EPG panel and placeholder are overlays on top.

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.channel,
    required this.player,
    required this.isFullscreen,
  });

  final ChannelLive? channel;
  final VlcPlayerController? player;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // ─ VlcPlayer — ALWAYS at tree-position index 0 ─────────────
            ColoredBox(
              color: Colors.black,
              child: StreamPlayerPage(controller: player),
            ),

            // ─ No-channel placeholder ───────────────────────────────────
            if (channel == null && !isFullscreen)
              ColoredBox(
                color: kColorBackDark,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FontAwesomeIcons.tv,
                        size: 48,
                        color: kColorHint,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Select a channel to play',
                        style: Get.textTheme.bodyMedium!.copyWith(
                          color: kColorHint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Press OK on a channel',
                        style: Get.textTheme.bodySmall!.copyWith(
                          color: kColorHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─ Channel info bar + EPG (bottom ~45%) ────────────────────
            if (channel != null && !isFullscreen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: constraints.maxHeight * 0.45,
                child: Column(
                  children: [
                    Container(
                      color: kColorCardDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          if (channel!.streamIcon != null &&
                              channel!.streamIcon!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CachedNetworkImage(
                                imageUrl: channel!.streamIcon!,
                                width: 22,
                                height: 22,
                                errorWidget: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              channel!.name ?? '',
                              style: Get.textTheme.bodyMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            FontAwesomeIcons.expand,
                            size: 11,
                            color: kColorHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'tap again',
                            style: Get.textTheme.bodySmall!.copyWith(
                              color: kColorHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _EpgPanel(streamId: channel!.streamId)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── EPG Panel ────────────────────────────────────────────────────────────────

class _EpgPanel extends StatelessWidget {
  const _EpgPanel({required this.streamId});
  final String? streamId;

  @override
  Widget build(BuildContext context) {
    if (streamId == null) return const SizedBox();
    return FutureBuilder<List<EpgModel>>(
      future: IpTvApi.getEPGbyStreamId(streamId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: kColorPrimary,
                strokeWidth: 2,
              ),
            ),
          );
        }
        final list = snap.data;
        if (list == null || list.isEmpty) {
          return Center(
            child: Text(
              'No EPG available',
              style: Get.textTheme.bodySmall!.copyWith(color: kColorHint),
            ),
          );
        }
        return Container(
          color: kColorCardLight,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => Container(
              height: 1,
              color: kColorCardDark,
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
            itemBuilder: (_, i) {
              final epg = list[i];
              final isNow = checkEpgTimeIsNow(epg.start ?? '', epg.end ?? '');
              String title = '', desc = '';
              try {
                title = utf8.decode(base64.decode(epg.title ?? ''));
                desc = utf8.decode(base64.decode(epg.description ?? ''));
              } catch (_) {}
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isNow)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kColorPrimary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NOW',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        '${getTimeFromDate(epg.start ?? '')} – ${getTimeFromDate(epg.end ?? '')}',
                        style: Get.textTheme.bodySmall!.copyWith(
                          color: kColorHint,
                        ),
                      ),
                    ],
                  ),
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: Get.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isNow ? kColorPrimary : Colors.white,
                      ),
                    ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: Get.textTheme.bodySmall!.copyWith(
                        color: Colors.white54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Fullscreen Controls Overlay (NO VlcPlayer — video stays in _PlayerPanel) ─
// Listens to controller via addListener for isBuffering / isPlaying state.
// Controls auto-hide after 4 s; tap anywhere to toggle.

class _LiveFullscreenControls extends StatefulWidget {
  const _LiveFullscreenControls({
    required this.controller,
    required this.channel,
    required this.onClose,
  });

  final VlcPlayerController controller;
  final ChannelLive channel;
  final VoidCallback onClose;

  @override
  State<_LiveFullscreenControls> createState() =>
      _LiveFullscreenControlsState();
}

class _LiveFullscreenControlsState extends State<_LiveFullscreenControls> {
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVlc);
    _syncState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(_LiveFullscreenControls old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onVlc);
      widget.controller.addListener(_onVlc);
      _syncState();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVlc);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _syncState() {
    final v = widget.controller.value;
    _isPlaying = v.isPlaying;
    _isBuffering = !v.isInitialized || v.isBuffering;
  }

  void _onVlc() {
    if (!mounted) return;
    final v = widget.controller.value;
    setState(() {
      _isPlaying = v.isPlaying;
      _isBuffering = !v.isInitialized || v.isBuffering;
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Buffering spinner (always visible when buffering)
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),

          // Controls (auto-hide)
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _buildControls(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xAA000000),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Back (exit fullscreen)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      FontAwesomeIcons.chevronDown,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Channel icon
                  if (widget.channel.streamIcon != null &&
                      widget.channel.streamIcon!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CachedNetworkImage(
                        imageUrl: widget.channel.streamIcon!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const SizedBox(),
                      ),
                    ),

                  // Channel name
                  Expanded(
                    child: Text(
                      widget.channel.name ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // LIVE badge
                  Container(
                    margin: const EdgeInsets.only(left: 10, right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  // Favourite
                  BlocBuilder<FavoritesCubit, FavoritesState>(
                    builder: (context, state) {
                      final liked = state.lives.any(
                        (l) => l.streamId == widget.channel.streamId,
                      );
                      return IconButton(
                        onPressed: () => context.read<FavoritesCubit>().addLive(
                          widget.channel,
                          isAdd: !liked,
                        ),
                        icon: Icon(
                          liked
                              ? FontAwesomeIcons.solidHeart
                              : FontAwesomeIcons.heart,
                          color: liked ? kColorPrimary : Colors.white,
                          size: 18,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Center play / pause ───────────────────────────────────
          const Spacer(),
          GestureDetector(
            onTap: _togglePlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                _isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const Spacer(),

          // ── Bottom padding ────────────────────────────────────────
          SafeArea(top: false, child: const SizedBox(height: 12)),
        ],
      ),
    );
  }
}
