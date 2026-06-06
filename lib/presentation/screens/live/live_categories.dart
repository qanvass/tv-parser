part of '../screens.dart';

// ─── LIVE TV — WIDESCREEN CATALOG ─────────────────────────────────────────────
// Layout: [Category Rail] | [Right Content (AI Search + Grid)]
//
// Optimized for Android TV / Google TV Leanback experience.
// No embedded local player; channel launch opens the standard player pathway
// using StreamLauncher and LivePlayerScreen.

const double _kItemH = 52.0;

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
  bool _chLoading = false;

  // ── D-pad focus state ─────────────────────────────────────────────────────
  // 0 = categories rail, 1 = channels grid
  int _panel = 0;
  bool _appbarActive = false;
  int _appbarIdx = 0;

  // ── Scroll / Focus Nodes ──────────────────────────────────────────────────
  final ScrollController _catScroll = ScrollController();
  final ScrollController _gridScroll = ScrollController();
  final FocusNode _navFocus = FocusNode();

  // ── AI Search ─────────────────────────────────────────────────────────────
  bool _showSearch = false;
  bool _isSearchEditing = false;
  bool _keepSearchOnFocusLoss = false;
  String _chSearch = '';
  Timer? _debounceTimer;

  final NativeTextFieldController _searchCtrl = NativeTextFieldController();
  final FocusNode _searchFocus = FocusNode();

  // TV Grid parameters
  static const int _gridColumns = 4;
  int get _appbarBtnMax => _showSearch ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChange);
    final s = context.read<LiveCatyBloc>().state;
    if (s is LiveCatySuccess && s.categories.isNotEmpty) {
      _initCats(s.categories);
    }

    if (!SearchIndexService.isReady) {
      _buildSearchIndex();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchFocus.removeListener(_onSearchFocusChange);
    _catScroll.dispose();
    _gridScroll.dispose();
    _navFocus.dispose();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buildSearchIndex() async {
    try {
      final api = IpTvApi();
      final results = await Future.wait([
        api.getLiveChannels(""),
        api.getMovieChannels(""),
        api.getSeriesChannels(""),
      ]);
      await SearchIndexService.buildIndex(
        liveChannels: results[0] as List<ChannelLive>,
        movies: results[1] as List<ChannelMovie>,
        series: results[2] as List<ChannelSerie>,
      );
    } catch (_) {}
  }

  void _onSearchFocusChange() {
    if (!_searchFocus.hasFocus && mounted) {
      if (_keepSearchOnFocusLoss) {
        _keepSearchOnFocusLoss = false;
        return; // Keep focus or restore D-pad navigation
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
      _chSearch = value.toLowerCase().trim();
      _isSearchEditing = false;
      _appbarActive = false;
      _chIdx = 0;
    });
    _navFocus.requestFocus();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _chSearch = value.toLowerCase().trim();
        _chIdx = 0;
      });
    });
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
      _appbarIdx = 1;
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

  void _selectCategory(int index) {
    _searchCtrl.clear();
    setState(() {
      _chSearch = '';
      _showSearch = false;
      _catIdx = index;
      _panel = 1;
      _chIdx = 0;
      _chLoading = true;
    });
    _fetchChannels(_cats[index].categoryId ?? '');
  }

  List<ChannelLive> get _displayStreams {
    if (_chSearch.isNotEmpty) {
      final intent = AiIntentMapper.parseQuery(_chSearch);
      final results = SearchIndexService.search(_chSearch, expandedKeywords: intent.keywords);
      return results
          .where((entry) => entry.type == 'live')
          .map((entry) => entry.item as ChannelLive)
          .toList();
    }
    return _chs;
  }

  Future<void> _play(ChannelLive ch) async {
    final user = await LocaleApi.getUser();
    final url =
        '${user!.serverInfo!.serverUrl}/${user.userInfo!.username}/${user.userInfo!.password}/${ch.streamId}';

    StreamLauncher.openStreamWithBrandedLoading(
      context: context,
      streamUrl: url,
      playerBuilder: () => LivePlayerScreen(
        link: url,
        title: ch.name ?? '',
        streamIcon: ch.streamIcon,
      ),
    );
  }

  // ── D-pad Traversal ───────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (_searchFocus.hasFocus || _isSearchEditing) return KeyEventResult.ignored;
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // ESC or Back key behavior
    if (k == LogicalKeyboardKey.escape) {
      if (_isSearchEditing) {
        _searchFocus.unfocus();
        setState(() {
          _isSearchEditing = false;
        });
        return KeyEventResult.handled;
      }
      if (_chSearch.isNotEmpty) {
        _searchCtrl.clear();
        setState(() {
          _chSearch = '';
          _showSearch = false;
          _chIdx = 0;
        });
        _navFocus.requestFocus();
        return KeyEventResult.handled;
      }
      Get.back();
      return KeyEventResult.handled;
    }

    // ── Appbar focused ──────────────────────────────────────────────────────
    if (_appbarActive) {
      if (k == LogicalKeyboardKey.arrowDown) {
        if (_panel == 0 && _cats.isNotEmpty) {
          setState(() => _appbarActive = false);
        } else if (_panel == 1 && _displayStreams.isNotEmpty) {
          setState(() => _appbarActive = false);
        }
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        if (_appbarIdx > 0) setState(() => _appbarIdx--);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        if (_appbarIdx < _appbarBtnMax) setState(() => _appbarIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _onAppbarSelect();
      }
      return KeyEventResult.handled;
    }

    // ── Category Rail focused ────────────────────────────────────────────────
    if (_panel == 0) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_catIdx > 0) {
          setState(() => _catIdx--);
          _scrollTo(_catScroll, _catIdx);
        } else {
          setState(() {
            _appbarActive = true;
            _appbarIdx = 0;
          });
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        if (_catIdx < _cats.length - 1) {
          setState(() => _catIdx++);
          _scrollTo(_catScroll, _catIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        if (_displayStreams.isNotEmpty) {
          setState(() {
            _panel = 1;
            _chIdx = 0;
          });
          _scrollGridTo(0);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _selectCategory(_catIdx);
        return KeyEventResult.handled;
      }
    }

    // ── Channel Grid focused ─────────────────────────────────────────────────
    if (_panel == 1) {
      final streams = _displayStreams;
      if (streams.isEmpty) return KeyEventResult.ignored;

      if (k == LogicalKeyboardKey.arrowLeft) {
        if (_chIdx % _gridColumns == 0) {
          setState(() => _panel = 0);
        } else {
          setState(() => _chIdx--);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        if (_chIdx < streams.length - 1) {
          setState(() => _chIdx++);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_chIdx >= _gridColumns) {
          setState(() => _chIdx -= _gridColumns);
          _scrollGridTo(_chIdx);
        } else {
          setState(() {
            _appbarActive = true;
            _appbarIdx = 0;
          });
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        if (_chIdx + _gridColumns < streams.length) {
          setState(() => _chIdx += _gridColumns);
          _scrollGridTo(_chIdx);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _play(streams[_chIdx]);
        return KeyEventResult.handled;
      }
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
        _activateSearchInput();
      } else {
        _searchCtrl.clear();
        setState(() {
          _chSearch = '';
          _showSearch = false;
          _isSearchEditing = false;
          _appbarActive = false;
          _chIdx = 0;
        });
        _navFocus.requestFocus();
      }
    } else {
      _openSearch();
    }
  }

  void _scrollTo(ScrollController sc, int idx) {
    if (!sc.hasClients) return;
    final target = (idx * (_kItemH + 6)).clamp(
      0.0,
      sc.position.maxScrollExtent,
    );
    sc.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _scrollGridTo(int idx) {
    if (!_gridScroll.hasClients) return;
    final row = idx ~/ _gridColumns;
    const double rowHeight = 156.0 + 16.0; // card height + spacing
    final target = (row * rowHeight).clamp(
      0.0,
      _gridScroll.position.maxScrollExtent,
    );
    _gridScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final displayStreams = _displayStreams;

    return PopScope(
      canPop: _chSearch.isEmpty && !_isSearchEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_isSearchEditing) {
            _searchFocus.unfocus();
            setState(() {
              _isSearchEditing = false;
            });
          } else if (_chSearch.isNotEmpty) {
            _searchCtrl.clear();
            setState(() {
              _chSearch = '';
              _showSearch = false;
              _chIdx = 0;
            });
            _navFocus.requestFocus();
          }
        }
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
              });
              if (_gridScroll.hasClients) _gridScroll.jumpTo(0);
            }
          },
          child: Focus(
            focusNode: _navFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Ink(
                decoration: kDecorBackground,
                child: Column(
                  children: [
                    // Safe top app bar spacing
                    SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 56,
                        child: _buildBar(),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Category Rail (width: 240px)
                          SizedBox(
                            width: 240,
                            child: _buildCategoryRail(),
                          ),
                          Container(width: 1, color: kColorCardLight),
                          // Right catalog grid area
                          Expanded(
                            child: _buildRightContent(displayStreams),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar() {
    return IptvAppBar(
      title: 'Live TV',
      icon: FontAwesomeIcons.towerBroadcast.data,
      onBack: Get.back,
      focusedIndex: _appbarActive ? _appbarIdx : null,
      showSearch: _showSearch,
      isSearchEditing: _isSearchEditing,
      searchHint: 'Search live channels...',
      searchController: _searchCtrl,
      searchFocus: _searchFocus,
      onSearchChanged: _onSearchChanged,
      onSearchToggle: _openSearch,
      onSearchActivate: _activateSearchInput,
      onSearchSubmitted: _onSearchSubmitted,
      onSearchClose: () {
        _searchCtrl.clear();
        setState(() {
          _chSearch = '';
          _showSearch = false;
          _isSearchEditing = false;
          _chIdx = 0;
        });
        _navFocus.requestFocus();
      },
    );
  }

  Widget _buildCategoryRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'CATEGORIES',
            style: Get.textTheme.bodySmall!.copyWith(
              color: kColorHint,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: _cats.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: kColorPrimary),
                )
              : ListView.builder(
                  controller: _catScroll,
                  cacheExtent: 350.0,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _cats.length,
                  itemBuilder: (_, i) {
                    final isSelected = i == _catIdx;
                    final isHighlighted = isSelected && _panel == 0 && !_appbarActive;

                    return GestureDetector(
                      onTap: () => _selectCategory(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        height: _kItemH,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kColorPrimary.withValues(alpha: .18)
                              : kColorCardLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHighlighted
                                ? const Color(0xFFFFC107) // Gold focus
                                : isSelected
                                ? kColorPrimary.withValues(alpha: .5)
                                : Colors.transparent,
                            width: isHighlighted ? 2.5 : 1.5,
                          ),
                          boxShadow: isHighlighted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFC107).withValues(alpha: .25),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.list.data,
                              size: 13,
                              color: isSelected ? const Color(0xFFFFC107) : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _cats[i].categoryName ?? '',
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
                                  color: Color(0xFFFFC107), // Gold dot
                                  shape: BoxShape.circle,
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
    );
  }

  Widget _buildRightContent(List<ChannelLive> displayStreams) {
    if (_chLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kColorPrimary),
      );
    }

    final hasSearch = _chSearch.isNotEmpty;
    final titleText = hasSearch
        ? 'AI Search: "$_chSearch"'
        : (_cats.isNotEmpty ? _cats[_catIdx].categoryName ?? '' : 'Catalog');
    final subtitleText = hasSearch
        ? 'Global Search • ${displayStreams.length} matches'
        : 'Full Catalog • 20,000+ discoverable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Count block
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Catalog Grid or Empty State
        Expanded(
          child: displayStreams.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  controller: _gridScroll,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  cacheExtent: 350.0,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridColumns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: displayStreams.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _chIdx;
                    final isItemFocused = isSelected && _panel == 1 && !_appbarActive;

                    return PremiumChannelCard(
                      title: displayStreams[index].name ?? 'Channel',
                      imageUrl: displayStreams[index].streamIcon,
                      isLive: true,
                      isTv: true,
                      isFocused: isItemFocused,
                      onTap: () => _play(displayStreams[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FontAwesomeIcons.magnifyingGlass.data,
            size: 40,
            color: kColorHint,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching channels found',
            style: Get.textTheme.bodyMedium!.copyWith(color: kColorHint, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Try searching for "ESPN", "CNN", "HBO", or "Fox"',
            style: Get.textTheme.bodySmall!.copyWith(color: kColorHint.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() {
                _chSearch = '';
                _showSearch = false;
                _chIdx = 0;
              });
              _navFocus.requestFocus();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFFC107),
                  width: 1.5,
                ),
              ),
              child: const Text(
                'Clear Search',
                style: TextStyle(
                  color: Color(0xFFFFC107),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
