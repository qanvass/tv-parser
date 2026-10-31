import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../helpers/tv_back_navigation.dart';
import '../../../repository/api/api.dart';
import '../../../repository/models/category.dart';
import '../../../repository/models/channel_live.dart';

/// Picks one live channel from the catalog already loaded for Live TV.
///
/// Adult categories stay out, matching the live rails. Search keeps at most
/// 200 matches so a large playlist does not build a tile per entry.
class MultiviewChannelPicker extends StatefulWidget {
  const MultiviewChannelPicker({super.key});

  @override
  State<MultiviewChannelPicker> createState() => _MultiviewChannelPickerState();
}

class _MultiviewChannelPickerState extends State<MultiviewChannelPicker> {
  static const int _searchCap = 200;
  static const double _rowExtent = 72;

  final FocusNode _searchFocus = FocusNode(debugLabel: 'MultiviewSearch');
  final FocusNode _categoryFocus = FocusNode(debugLabel: 'MultiviewCategory');
  final FocusNode _resultsFocus = FocusNode(debugLabel: 'MultiviewResults');
  final ScrollController _scroll = ScrollController();
  final TextEditingController _queryController = TextEditingController();
  final TvBackGate _backGate = TvBackGate();

  List<ChannelLive> _channels = const [];
  List<CategoryModel> _categories = const [];
  List<ChannelLive> _results = const [];
  int _categoryIndex = 0;
  int _cursor = 0;
  bool _ready = false;
  bool _capped = false;
  Timer? _searchDebounce;
  String _query = '';
  final DateTime _ignoreSelectUntil = DateTime.now().add(
    const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _searchFocus.onKeyEvent = _onSearchKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _categoryFocus.dispose();
    _resultsFocus.dispose();
    _scroll.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _load() {
    final session = IptvProviderSession.instance;
    final cats = session.categoriesForAction('get_live_categories');
    final adultIds = <String>{};
    final visibleCats = <CategoryModel>[];
    for (final cat in cats) {
      final name = cat.categoryName;
      if (name != null && ProviderCurationRules.isAdultCategory(name)) {
        final id = cat.categoryId;
        if (id != null && id.isNotEmpty) adultIds.add(id);
        continue;
      }
      visibleCats.add(cat);
    }
    final sorted = ProviderCurationRules.sortCategoriesForNormalDashboard(
      visibleCats,
    );
    final channels = <ChannelLive>[];
    for (final ch in session.liveChannels()) {
      final id = ch.streamId?.trim() ?? '';
      if (id.isEmpty) continue;
      final catId = ch.categoryId;
      if (catId != null && adultIds.contains(catId)) continue;
      final adultFlag = (ch.isAdult ?? '').toLowerCase();
      if (adultFlag == '1' || adultFlag == 'true') continue;
      channels.add(ch);
    }
    _channels = channels;
    _categories = sorted;
    _rebuildResults();
    if (!mounted) return;
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_results.isNotEmpty) {
        _resultsFocus.requestFocus();
      } else {
        _categoryFocus.requestFocus();
      }
    });
  }

  void _rebuildResults() {
    final catId = _categoryIndex == 0
        ? null
        : _categories[_categoryIndex - 1].categoryId;
    final needle = _query;
    final out = <ChannelLive>[];
    var capped = false;
    for (final ch in _channels) {
      if (catId != null && catId.isNotEmpty && ch.categoryId != catId) {
        continue;
      }
      if (needle.isNotEmpty) {
        final name = (ch.name ?? '').toLowerCase();
        if (!name.contains(needle)) continue;
      }
      out.add(ch);
      if (needle.isNotEmpty && out.length >= _searchCap) {
        capped = true;
        break;
      }
    }
    _results = out;
    _capped = capped;
    _cursor = 0;
  }

  void _onQuery(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _query = value.trim().toLowerCase();
      setState(_rebuildResults);
      _revealCursor();
    });
  }

  String get _categoryLabel {
    if (_categoryIndex <= 0) return 'All';
    return _categories[_categoryIndex - 1].categoryName ?? 'Live';
  }

  void _stepCategory(int delta) {
    final last = _categories.length;
    final next = (_categoryIndex + delta).clamp(0, last);
    if (next == _categoryIndex) return;
    setState(() {
      _categoryIndex = next;
      _rebuildResults();
    });
    _revealCursor();
  }

  void _moveCursor(int delta) {
    if (_results.isEmpty) return;
    final next = (_cursor + delta).clamp(0, _results.length - 1);
    if (next == _cursor) return;
    setState(() => _cursor = next);
    _revealCursor();
  }

  void _revealCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _results.isEmpty) return;
      final target = _cursor * _rowExtent;
      final position = _scroll.position;
      final view = position.viewportDimension;
      if (target < position.pixels) {
        _scroll.jumpTo(target);
      } else if (target + _rowExtent > position.pixels + view) {
        _scroll.jumpTo(target + _rowExtent - view);
      }
    });
  }

  void _close() {
    if (!mounted) return;
    if (!_backGate.allow(screen: 'MultiviewPicker', source: 'focus')) return;
    _backGate.markRouteExit();
    logTvBack(
      screen: 'MultiviewPicker',
      source: 'focus',
      action: 'popRoute',
      blockedDuplicate: false,
      routeBefore: Get.currentRoute,
    );
    Navigator.of(context).pop();
  }

  void _choose() {
    if (_results.isEmpty || _cursor < 0 || _cursor >= _results.length) return;
    if (!mounted) return;
    Navigator.of(context).pop(_results[_cursor]);
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.numpadEnter;

  bool _swallowFreshSelect(KeyEvent event) {
    if (!_isSelect(event.logicalKey)) return false;
    return DateTime.now().isBefore(_ignoreSelectUntil);
  }

  KeyEventResult _onSearchKey(FocusNode _, KeyEvent event) {
    if (_swallowFreshSelect(event)) return KeyEventResult.handled;
    if (isTvBackKey(event.logicalKey)) {
      if (event is KeyDownEvent) _close();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _categoryFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCategoryKey(FocusNode _, KeyEvent event) {
    if (_swallowFreshSelect(event)) return KeyEventResult.handled;
    if (isTvBackKey(event.logicalKey)) {
      if (event is KeyDownEvent) _close();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _stepCategory(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _stepCategory(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || _isSelect(key)) {
      if (_results.isNotEmpty) {
        _resultsFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onResultsKey(FocusNode _, KeyEvent event) {
    if (_swallowFreshSelect(event)) return KeyEventResult.handled;
    if (isTvBackKey(event.logicalKey)) {
      if (event is KeyDownEvent) _close();
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_cursor <= 0) {
        _categoryFocus.requestFocus();
      } else {
        _moveCursor(-1);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (event is KeyDownEvent) _choose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose a channel',
                style: TextStyle(
                  color: Color(0xFFF7F7F8),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Left and right change category. OK picks. Back returns.',
                style: TextStyle(
                  color: Color(0xFFB8B8C0),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                focusNode: _searchFocus,
                controller: _queryController,
                onChanged: _onQuery,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search live channels',
                  hintStyle: const TextStyle(color: Color(0x88FFFFFF)),
                  filled: true,
                  fillColor: const Color(0x14FFFFFF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x38FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Focus(
                focusNode: _categoryFocus,
                onKeyEvent: _onCategoryKey,
                child: ListenableBuilder(
                  listenable: _categoryFocus,
                  builder: (context, _) {
                    final focused = _categoryFocus.hasFocus;
                    return Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: focused ? Colors.white : const Color(0x38FFFFFF),
                          width: focused ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        _categoryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xCCF2F2F5),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No live channels in this list',
          style: TextStyle(
            color: Color(0xFFB8B8C0),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Focus(
      focusNode: _resultsFocus,
      onFocusChange: (_) {
        if (mounted) setState(() {});
      },
      onKeyEvent: _onResultsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_capped)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Showing the first 200 matches. Keep typing to narrow the list.',
                style: TextStyle(
                  color: Color(0xFFB8B8C0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemExtent: _rowExtent,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final ch = _results[index];
                final selected = index == _cursor && _resultsFocus.hasFocus;
                final name = (ch.name ?? '').trim().isEmpty
                    ? 'Live channel'
                    : ch.name!.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? const Color(0x33FFFFFF)
                        : const Color(0x10FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => _cursor = index);
                        _resultsFocus.requestFocus();
                        _choose();
                      },
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : const Color(0x22FFFFFF),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
