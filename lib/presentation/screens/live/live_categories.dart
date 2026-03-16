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

  // ── Appbar focus ──────────────────────────────────────────────────────────
  bool _appbarActive = false;
  int _appbarIdx = 0;
  // search mode: back=0, input=1, close=2 | normal: back=0, fav=1, search=2
  int get _appbarBtnMax => _showSearch ? 2 : (_selCh != null ? 2 : 1);

  // ── Scroll / focus ────────────────────────────────────────────────────────
  final _catScroll = ScrollController();
  final _chScroll = ScrollController();
  final _navFocus = FocusNode();

  // ── Search (appbar) ───────────────────────────────────────────────────────
  bool _showSearch = false;
  bool _isSearchEditing = false;
  bool _keepSearchOnFocusLoss = false;
  final _searchCtrl = NativeTextFieldController();
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
      if (_keepSearchOnFocusLoss) {
        _keepSearchOnFocusLoss = false;
        return; // Done pressed — keep search visible, focus on items
      }
      setState(() {
        _showSearch = false;
        _isSearchEditing = false;
      });
      _navFocus.requestFocus();
    }
  }

  void _onSearchSubmitted(String value) {
    _keepSearchOnFocusLoss = true;
    setState(() {
      _chSearch = value.toLowerCase();
      _isSearchEditing = false;
      _appbarActive = false;
    });
    _navFocus.requestFocus();
  }

  void _activateSearchInput() {
    setState(() => _isSearchEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _openSearch() {
    setState(() {
      _showSearch = true;
      _appbarActive = true;
      _appbarIdx = 1; // land D-pad on the input field
    });
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

    // Reuse existing controller — swap stream in-place so VlcPlayer stays in tree
    if (_player != null && _player!.value.isInitialized) {
      try {
        await _player!.setMediaFromNetwork(
          url,
          autoPlay: true,
          hwAcc: HwAcc.full,
        );
        if (mounted)
          setState(() {
            _selCh = ch;
            _chIdx = idx;
          });
        return;
      } catch (_) {}
    }

    // First launch or fallback: create a fresh controller
    final old = _player;
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

    // Dispose old after state is updated (VlcPlayer has already detached from it)
    if (old != null) {
      old.stopRendererScanning().catchError((_) {});
      old.dispose();
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
      // Return focus to the outer panel when exiting fullscreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navFocus.requestFocus();
      });
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
    if (_isFullscreen) return KeyEventResult.ignored;
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // ── Appbar active ──────────────────────────────────────────────────────
    if (_appbarActive) {
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() => _appbarActive = false);
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        if (_appbarIdx > 0) setState(() => _appbarIdx--);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        if (_appbarIdx < _appbarBtnMax) setState(() => _appbarIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _onAppbarSelect();
      } else if (k == LogicalKeyboardKey.escape) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_panel > 0) setState(() => _panel--);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_panel < 1) setState(() => _panel++);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      final atTop =
          (_panel == 0 && _catIdx == 0) || (_panel == 1 && _chIdx == 0);
      if (atTop) {
        setState(() {
          _appbarActive = true;
          _appbarIdx = 0;
        });
      } else {
        _dpadUp();
      }
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

  void _onAppbarSelect() {
    if (_appbarIdx == 0) {
      Get.back();
      return;
    }
    if (_showSearch) {
      if (_appbarIdx == 1) {
        _activateSearchInput(); // focus on input → open keyboard
      } else {
        // idx == 2: close search
        _searchCtrl.clear();
        setState(() {
          _chSearch = '';
          _showSearch = false;
          _isSearchEditing = false;
          _appbarActive = false;
        });
        _navFocus.requestFocus();
      }
      return;
    }
    if (_selCh != null && _appbarIdx == 1) {
      final favState = context.read<FavoritesCubit>().state;
      final liked = favState.lives.any((l) => l.streamId == _selCh!.streamId);
      context.read<FavoritesCubit>().addLive(_selCh, isAdd: !liked);
    } else {
      _openSearch();
    }
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
    return IptvAppBar(
      title: 'Live TV',
      icon: FontAwesomeIcons.towerBroadcast,
      onBack: Get.back,
      focusedIndex: _appbarActive ? _appbarIdx : null,
      showSearch: _showSearch,
      isSearchEditing: _isSearchEditing,
      searchHint: 'Search channels...',
      searchController: _searchCtrl,
      searchFocus: _searchFocus,
      onSearchChanged: (v) => setState(() => _chSearch = v.toLowerCase()),
      onSearchToggle: _openSearch,
      onSearchActivate: _activateSearchInput,
      onSearchSubmitted: _onSearchSubmitted,
      onSearchClose: () {
        _searchCtrl.clear();
        setState(() {
          _chSearch = '';
          _showSearch = false;
          _isSearchEditing = false;
        });
        _navFocus.requestFocus();
      },
      trailing: [
        if (_selCh != null)
          BlocBuilder<FavoritesCubit, FavoritesState>(
            builder: (context, state) {
              final liked = state.lives.any(
                (l) => l.streamId == _selCh!.streamId,
              );
              return IptvAppBarAction(
                icon: liked
                    ? FontAwesomeIcons.solidHeart
                    : FontAwesomeIcons.heart,
                color: liked ? kColorPrimary : Colors.white,
                isFocused: _appbarActive && _appbarIdx == 1,
                onTap: () => context.read<FavoritesCubit>().addLive(
                  _selCh,
                  isAdd: !liked,
                ),
              );
            },
          ),
      ],
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
// Layout: Column with two equal halves:
//   Top  (flex 11) — video player, ALWAYS in tree at this position
//   Bottom (flex 9) — channel info + EPG (only when channel selected & not fullscreen)
//
// IMPORTANT: StreamPlayerPage (VlcPlayer) must never be removed from the tree.
// It lives at Column → Expanded → ColoredBox → Stack → StreamPlayerPage.
// That path is constant regardless of EPG visibility.

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
    final showEpg = channel != null && !isFullscreen;

    return Column(
      children: [
        // ── Video (top half) — VlcPlayer ALWAYS lives here ────────────
        Expanded(
          flex: 11,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                StreamPlayerPage(controller: player),

                // No-channel placeholder overlaid on black bg
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
              ],
            ),
          ),
        ),

        // ── EPG (bottom half) ─────────────────────────────────────────
        if (showEpg) ...[
          Container(height: 1, color: kColorCardLight),
          Expanded(
            flex: 9,
            child: Column(
              children: [
                // Channel info bar
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
      ],
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

// ─── Fullscreen Controls Overlay ──────────────────────────────────────────────
// Tap anywhere → toggle controls.  D-pad navigates buttons.
// Top row:    [Back]  [channel icon + name]  [LIVE]  [SUB badge]  [AUD badge]
// Bottom row: [-10s (VOD)]  [▶/⏸]  [slider (VOD)]  [⊞ exit]

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
  // Aspect ratios to cycle through
  static const _kAspects = ['16:9', '4:3', '1:1', '21:9'];
  int _aspectIdx = 0;

  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = true;
  Timer? _hideTimer;

  // Tracks
  Map<int, String> _audioTracks = {};
  Map<int, String> _subtitleTracks = {};
  bool _tracksLoaded = false;

  // Track panel: null=closed, 'sub'|'audio'=open
  String? _trackPanel;
  int _trackPanelIdx = 0;
  List<MapEntry<int, String>> get _trackList => _trackPanel == 'sub'
      ? _subtitleTracks.entries.toList()
      : _audioTracks.entries.toList();

  // Position
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool get _isLive => _duration.inSeconds < 5;

  // D-pad focus
  // Row 0 (top):    0=back, 1=sub, 2=audio
  // Row 1 (bottom): live=[0=play,1=exit]  vod=[0=rewind,1=play,2=exit]
  int _focusRow = 1;
  int _focusCol = 0; // default: play

  final _focusNode = FocusNode();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVlc);
    _syncState();
    _scheduleHide();
    _loadTracks();
    // Explicitly steal focus from the outer panel — autofocus alone won't
    // win if the parent Focus node is already focused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(_LiveFullscreenControls old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onVlc);
      widget.controller.addListener(_onVlc);
      _syncState();
      _tracksLoaded = false;
      _audioTracks = {};
      _subtitleTracks = {};
      _loadTracks();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVlc);
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncState() {
    final v = widget.controller.value;
    _isPlaying = v.isPlaying;
    _isBuffering = !v.isInitialized || v.isBuffering;
    _position = v.position;
    _duration = v.duration;
  }

  void _onVlc() {
    if (!mounted) return;
    final v = widget.controller.value;
    setState(() {
      _isPlaying = v.isPlaying;
      _isBuffering = !v.isInitialized || v.isBuffering;
      _position = v.position;
      _duration = v.duration;
    });
    if (v.isInitialized && !_tracksLoaded) {
      _tracksLoaded = true;
      _loadTracks();
    }
  }

  Future<void> _loadTracks() async {
    if (!widget.controller.value.isInitialized) return;
    try {
      final audio = await widget.controller.getAudioTracks();
      final sub = await widget.controller.getSpuTracks();
      if (mounted) {
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = sub;
        });
      }
    } catch (_) {}
  }

  // ── Timers ────────────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_trackPanel != null) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showAndReschedule() {
    setState(() => _showControls = true);
    _scheduleHide();
  }

  void _onTap() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      _showAndReschedule();
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _togglePlay() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _scheduleHide();
  }

  Future<void> _rewind10s() async {
    try {
      final target = _position - const Duration(seconds: 30);
      await widget.controller.seekTo(
        target < Duration.zero ? Duration.zero : target,
      );
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _cycleAspect() async {
    final nextIdx = (_aspectIdx + 1) % _kAspects.length;
    try {
      await widget.controller.setVideoAspectRatio(_kAspects[nextIdx]);
    } catch (_) {}
    if (mounted) setState(() => _aspectIdx = nextIdx);
    _scheduleHide();
  }

  void _openTrackPanel(String type) {
    setState(() {
      _trackPanel = type;
      _trackPanelIdx = 0;
    });
    _hideTimer?.cancel();
  }

  void _selectTrack(int trackId) {
    try {
      if (_trackPanel == 'sub') {
        widget.controller.setSpuTrack(trackId);
      } else {
        widget.controller.setAudioTrack(trackId);
      }
    } catch (_) {}
    setState(() => _trackPanel = null);
    _scheduleHide();
  }

  // ── D-pad navigation ──────────────────────────────────────────────────────

  int get _bottomMax => _isLive ? 1 : 2;

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  // bottom col → logical action
  String _bottomAction(int col) {
    if (_isLive) return col == 0 ? 'play' : 'aspect';
    return ['rewind', 'play', 'aspect'][col];
  }

  void _activateFocused() {
    if (_focusRow == 0) {
      switch (_focusCol) {
        case 0:
          widget.onClose();
        case 1:
          if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
        case 2:
          if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
      }
    } else {
      switch (_bottomAction(_focusCol)) {
        case 'rewind':
          _rewind10s();
        case 'play':
          _togglePlay();
        case 'aspect':
          _cycleAspect();
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // Track panel open → navigate it
    if (_trackPanel != null) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_trackPanelIdx > 0) setState(() => _trackPanelIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_trackPanelIdx < _trackList.length - 1)
          setState(() => _trackPanelIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        if (_trackList.isNotEmpty) _selectTrack(_trackList[_trackPanelIdx].key);
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _trackPanel = null);
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }

    // Controls hidden → any key shows them
    if (!_showControls) {
      _showAndReschedule();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusRow == 1)
        setState(() {
          _focusRow = 0;
          _focusCol = _focusCol.clamp(0, 2);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow == 0)
        setState(() {
          _focusRow = 1;
          _focusCol = _focusCol.clamp(0, _bottomMax);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      final max = _focusRow == 0 ? 2 : _bottomMax;
      if (_focusCol < max) setState(() => _focusCol++);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      _activateFocused();
    } else if (k == LogicalKeyboardKey.escape) {
      widget.onClose();
    }
    return KeyEventResult.handled;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Buffering spinner
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xCC000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                      stops: [0.0, 0.25, 0.75, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const Spacer(),
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ),
            ),

            // Track selection panel
            if (_trackPanel != null) _buildTrackPanel(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Back / exit fullscreen
            _FsBtn(
              icon: FontAwesomeIcons.chevronDown,
              label: 'Back',
              isFocused: _isFocused(0, 0),
              onTap: widget.onClose,
            ),
            const SizedBox(width: 8),

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
              margin: const EdgeInsets.only(left: 8, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

            // Subtitle tracks
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty
                  ? '${_subtitleTracks.length}'
                  : null,
              isFocused: _isFocused(0, 1),
              isDisabled: _subtitleTracks.isEmpty,
              onTap: () => _openTrackPanel('sub'),
            ),
            const SizedBox(width: 8),

            // Audio tracks
            _FsBtn(
              icon: FontAwesomeIcons.volumeHigh,
              label: 'AUD',
              badge: _audioTracks.isNotEmpty ? '${_audioTracks.length}' : null,
              isFocused: _isFocused(0, 2),
              isDisabled: _audioTracks.isEmpty,
              onTap: () => _openTrackPanel('audio'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Rewind 10 s (VOD only)
            if (!_isLive) ...[
              _FsBtn(
                icon: FontAwesomeIcons.rotateLeft,
                label: '-10s',
                isFocused: _isFocused(1, 0),
                onTap: _rewind10s,
              ),
              const SizedBox(width: 12),
            ],

            // Play / Pause
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              label: _isPlaying ? 'Pause' : 'Play',
              isFocused: _isFocused(1, _isLive ? 0 : 1),
              isLarge: true,
              onTap: _togglePlay,
            ),
            const SizedBox(width: 12),

            // Progress slider (VOD only) / spacer for live
            if (!_isLive) ...[
              Expanded(child: _buildSlider()),
              const SizedBox(width: 12),
            ] else
              const Spacer(),

            // Aspect ratio cycle
            _FsBtn(
              icon: FontAwesomeIcons.expand,
              label: _kAspects[_aspectIdx],
              isFocused: _isFocused(1, _isLive ? 1 : 2),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider() {
    final total = _duration.inMilliseconds;
    final pos = total > 0
        ? (_position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kColorPrimary,
            inactiveTrackColor: Colors.white24,
            thumbColor: kColorFocus,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            trackHeight: 3,
          ),
          child: Slider(
            value: pos,
            onChanged: (v) async {
              try {
                final target = Duration(milliseconds: (v * total).round());
                await widget.controller.seekTo(target);
              } catch (_) {}
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(_position),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              _fmt(_duration),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Track selection panel ─────────────────────────────────────────────────

  Widget _buildTrackPanel() {
    final list = _trackList;
    final isSubPanel = _trackPanel == 'sub';
    return Positioned(
      top: 72,
      right: 16,
      child: Container(
        width: 220,
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: const Color(0xF0101018),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSubPanel
                        ? FontAwesomeIcons.closedCaptioning
                        : FontAwesomeIcons.volumeHigh,
                    size: 12,
                    color: kColorPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSubPanel ? 'SUBTITLES' : 'AUDIO TRACKS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),

            // Track list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final focused = i == _trackPanelIdx;
                  return GestureDetector(
                    onTap: () => _selectTrack(list[i].key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? kColorPrimary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: focused ? kColorFocus : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        list[i].value.isNotEmpty
                            ? list[i].value
                            : 'Track ${i + 1}',
                        style: TextStyle(
                          color: focused ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: focused
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fullscreen control button ─────────────────────────────────────────────────

class _FsBtn extends StatelessWidget {
  const _FsBtn({
    required this.icon,
    required this.label,
    required this.isFocused,
    required this.onTap,
    this.badge,
    this.isDisabled = false,
    this.isLarge = false,
  });

  final IconData icon;
  final String label;
  final bool isFocused;
  final VoidCallback onTap;
  final String? badge;
  final bool isDisabled;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDisabled
        ? Colors.white24
        : isFocused
        ? Colors.white
        : Colors.white70;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isLarge ? 16 : 12,
              vertical: isLarge ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: isFocused
                  ? kColorPrimary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFocused
                    ? kColorFocus
                    : Colors.white.withValues(alpha: isDisabled ? 0.1 : 0.2),
                width: isFocused ? 1.5 : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: kColorFocus.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(icon, size: isLarge ? 18 : 14, color: baseColor),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      color: baseColor,
                      fontSize: isLarge ? 13 : 11,
                      fontWeight: isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -7,
              right: -7,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: kColorPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
