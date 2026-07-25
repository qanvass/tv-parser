import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/blocs/categories/live_caty/live_caty_bloc.dart';
import '../../repository/api/api.dart';
import '../../repository/models/category.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/api/playback_url_builder.dart';
import '../../repository/api/provider_curation_rules.dart';
import '../screens/screens.dart';
import '../shared/widgets/stream_launcher.dart';

class AdultContentScreen extends StatefulWidget {
  const AdultContentScreen({super.key});

  @override
  State<AdultContentScreen> createState() => _AdultContentScreenState();
}

class _AdultContentScreenState extends State<AdultContentScreen> {
  List<CategoryModel> _adultCategories = [];
  CategoryModel? _selectedCategory;
  List<ChannelLive> _loadedStreams = [];
  List<ChannelLive> _filteredStreams = [];
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdultCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAdultCategories() {
    final liveState = context.read<LiveCatyBloc>().state;
    if (liveState is LiveCatySuccess) {
      _adultCategories = liveState.categories
          .where(
            (c) =>
                c.categoryName != null &&
                ProviderCurationRules.isAdultCategory(c.categoryName!),
          )
          .toList();
    }
    if (_adultCategories.isNotEmpty) {
      _onCategorySelected(_adultCategories.first);
    }
  }

  void _onCategorySelected(CategoryModel category) async {
    setState(() {
      _selectedCategory = category;
      _loadedStreams = [];
      _filteredStreams = [];
      _loading = true;
    });

    try {
      final api = IpTvApi();
      final data = await api.getLiveChannels(category.categoryId ?? '');

      if (mounted) {
        setState(() {
          _loadedStreams = data;
          _filteredStreams = data;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String val) {
    final clean = val.toLowerCase().trim();
    if (clean.isEmpty) {
      setState(() {
        _filteredStreams = _loadedStreams;
      });
    } else {
      setState(() {
        _filteredStreams = _loadedStreams
            .where((ch) => (ch.name ?? '').toLowerCase().contains(clean))
            .toList();
      });
    }
  }

  void _playChannel(ChannelLive ch) async {
    if (ch.streamId != null) {
      final streamUrl = await PlaybackUrlBuilder.buildLiveUrl(ch.streamId!);
      if (streamUrl.isNotEmpty) {
        StreamLauncher.openStreamWithBrandedLoading(
          context: context,
          streamUrl: streamUrl,
          playerBuilder: () => MoviePlayerScreen(
            link: streamUrl,
            title: ch.name ?? 'Adult Channel',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13101E),
        elevation: 0,
        title: const Text(
          "Adult / 18+",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [
              const Color(0xFF1B0B24).withOpacity(0.3),
              const Color(0xFF090810),
            ],
          ),
        ),
        child: Column(
          children: [
            // Category Selector
            if (_adultCategories.isNotEmpty)
              Container(
                height: 54,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _adultCategories.length,
                  itemBuilder: (context, idx) {
                    final cat = _adultCategories[idx];
                    final isSelected =
                        _selectedCategory?.categoryId == cat.categoryId;
                    return _FocusableTap(
                      autofocus: idx == 0,
                      onActivate: () => _onCategorySelected(cat),
                      child: Container(
                        margin: const EdgeInsets.only(
                          right: 10,
                          top: 8,
                          bottom: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.shade900
                              : const Color(0xFF1E1A30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.red : Colors.white12,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat.categoryName ?? 'Category',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Local Search Bar
            if (_adultCategories.isNotEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search adult channels...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white30,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1A30),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

            // Main Content Area
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    )
                  : _adultCategories.isEmpty
                  ? const Center(
                      child: Text(
                        "No adult channels found for this provider.",
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : _filteredStreams.isEmpty
                  ? const Center(
                      child: Text(
                        "No channels match your search.",
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      itemCount: _filteredStreams.length,
                      itemBuilder: (context, idx) {
                        final ch = _filteredStreams[idx];
                        return _FocusableTap(
                          autofocus: idx == 0,
                          onActivate: () => _playChannel(ch),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161224),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // App-store-safe lock artwork card placeholder instead of explicit thumbnails
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF28102A),
                                        Color(0xFF0F0E17),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 32,
                                      color: Colors.red.shade900.withOpacity(
                                        0.4,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black87,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      ch.name ?? 'Adult Channel',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
    );
  }
}

/// Wraps [child] so it's reachable and activatable via D-pad/remote
/// (Select/Enter/Space) in addition to touch — this screen has no
/// touchscreen-only affordances once wrapped.
class _FocusableTap extends StatefulWidget {
  const _FocusableTap({
    required this.onActivate,
    required this.child,
    this.autofocus = false,
  });

  final VoidCallback onActivate;
  final Widget child;
  final bool autofocus;

  @override
  State<_FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<_FocusableTap> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          widget.onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onActivate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: _focused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent, width: 2.5),
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
