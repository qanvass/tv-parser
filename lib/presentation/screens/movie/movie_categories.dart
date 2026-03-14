part of '../screens.dart';

const double _kMovieItemH = 52.0;

class MovieCategoriesScreen extends StatefulWidget {
  const MovieCategoriesScreen({super.key});

  @override
  State<MovieCategoriesScreen> createState() => _MovieCategoriesScreenState();
}

class _MovieCategoriesScreenState extends State<MovieCategoriesScreen> {
  List<CategoryModel> _cats = [];
  int _catIdx = 0;

  List<ChannelMovie> _movies = [];
  int _movieIdx = 0;
  String _movieSearch = '';
  bool _movieLoading = false;

  int _panel = 0;

  final _catScroll = ScrollController();
  final _gridScroll = ScrollController();
  final _navFocus = FocusNode();

  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChange);
    final s = context.read<MovieCatyBloc>().state;
    if (s is MovieCatySuccess && s.categories.isNotEmpty) {
      _initCats(s.categories);
    }
  }

  void _onSearchFocusChange() {
    if (!_searchFocus.hasFocus && mounted) {
      _searchCtrl.clear();
      setState(() {
        _showSearch = false;
        _movieSearch = '';
      });
      _navFocus.requestFocus();
    }
  }

  void _initCats(List<CategoryModel> cats) {
    if (_cats.isNotEmpty) return;
    _cats = cats;
    _fetchMovies(cats[0].categoryId ?? '');
  }

  void _fetchMovies(String catyId) {
    setState(() {
      _movies = [];
      _movieIdx = 0;
      _movieLoading = true;
    });
    context.read<ChannelsBloc>().add(
      GetLiveChannelsEvent(catyId: catyId, typeCategory: TypeCategory.movies),
    );
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChange);
    _catScroll.dispose();
    _gridScroll.dispose();
    _navFocus.dispose();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (_searchFocus.hasFocus) return KeyEventResult.ignored;
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_panel == 1) _dpadLeft();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_panel == 0) {
        setState(() => _panel = 1);
      } else {
        _dpadRight();
      }
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

  static const int _gridColumns = 5;

  void _dpadUp() {
    if (_panel == 0) {
      if (_catIdx > 0) {
        setState(() => _catIdx--);
        _scrollTo(_catScroll, _catIdx);
      }
    } else {
      if (_movieIdx >= _gridColumns) {
        setState(() => _movieIdx -= _gridColumns);
        _scrollGridTo(_movieIdx);
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
      if (_movieIdx + _gridColumns < _filteredMovies.length) {
        setState(() => _movieIdx += _gridColumns);
        _scrollGridTo(_movieIdx);
      }
    }
  }

  void _scrollGridTo(int idx) {
    if (!_gridScroll.hasClients) return;
    final row = idx ~/ _gridColumns;
    const itemHeight = 180.0;
    final target = (row * itemHeight).clamp(
      0.0,
      _gridScroll.position.maxScrollExtent,
    );
    _gridScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _dpadLeft() {
    if (_movieIdx > 0) {
      setState(() => _movieIdx--);
    } else {
      setState(() => _panel = 0);
    }
  }

  void _dpadRight() {
    if (_movieIdx < _filteredMovies.length - 1) {
      setState(() => _movieIdx++);
    }
  }

  void _dpadSelect() {
    if (_panel == 0 && _cats.isNotEmpty) {
      _fetchMovies(_cats[_catIdx].categoryId ?? '');
      setState(() => _panel = 1);
    } else if (_panel == 1 && _filteredMovies.isNotEmpty) {
      final movie = _filteredMovies[_movieIdx];
      Get.to(
        () => MovieContent(channelMovie: movie, videoId: movie.streamId ?? ''),
      );
    }
  }

  void _scrollTo(ScrollController sc, int idx) {
    if (!sc.hasClients) return;
    final target = (idx * (_kMovieItemH + 4)).clamp(
      0.0,
      sc.position.maxScrollExtent,
    );
    sc.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  List<ChannelMovie> get _filteredMovies {
    if (_movieSearch.isEmpty) return _movies;
    return _movies
        .where((m) => (m.name ?? '').toLowerCase().contains(_movieSearch))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MovieCatyBloc, MovieCatyState>(
      listener: (_, s) {
        if (s is MovieCatySuccess) _initCats(s.categories);
      },
      child: BlocListener<ChannelsBloc, ChannelsState>(
        listener: (_, s) {
          if (s is ChannelsMovieSuccess && mounted) {
            setState(() {
              _movies = s.channels;
              _movieLoading = false;
              _movieIdx = 0;
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
                  SafeArea(
                    bottom: false,
                    child: SizedBox(height: 56, child: _buildBar()),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 210,
                          child: _MoviePanel(
                            label: 'CATEGORIES',
                            isLoading: _cats.isEmpty,
                            scroll: _catScroll,
                            itemCount: _cats.length,
                            itemBuilder: (i) => _MoviePanelItem(
                              icon: FontAwesomeIcons.list,
                              label: _cats[i].categoryName ?? '',
                              isSelected: i == _catIdx,
                              isHighlighted: i == _catIdx && _panel == 0,
                              onTap: () {
                                setState(() {
                                  _catIdx = i;
                                  _panel = 1;
                                });
                                _fetchMovies(_cats[i].categoryId ?? '');
                              },
                            ),
                          ),
                        ),
                        Container(width: 1, color: kColorCardLight),
                        Expanded(
                          child: _MovieGridPanel(
                            movies: _filteredMovies,
                            selectedIdx: _movieIdx,
                            isGridFocused: _panel == 1,
                            isLoading: _movieLoading,
                            scrollController: _gridScroll,
                            onMovieTap: (movie, idx) {
                              Get.to(
                                () => MovieContent(
                                  channelMovie: movie,
                                  videoId: movie.streamId ?? '',
                                ),
                              );
                            },
                          ),
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
    );
  }

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
            const Icon(FontAwesomeIcons.film, size: 16, color: kColorPrimary),
            const Spacer(),
          ] else ...[
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                onChanged: (v) =>
                    setState(() => _movieSearch = v.toLowerCase()),
                style: Get.textTheme.bodyMedium!.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search movies...',
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
                  _movieSearch = '';
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

class _MoviePanel extends StatelessWidget {
  const _MoviePanel({
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

class _MoviePanelItem extends StatelessWidget {
  const _MoviePanelItem({
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
        height: _kMovieItemH,
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

class _MovieGridPanel extends StatelessWidget {
  const _MovieGridPanel({
    required this.movies,
    required this.selectedIdx,
    required this.isGridFocused,
    required this.isLoading,
    required this.onMovieTap,
    required this.scrollController,
  });

  final List<ChannelMovie> movies;
  final int selectedIdx;
  final bool isGridFocused;
  final bool isLoading;
  final Function(ChannelMovie, int) onMovieTap;
  final ScrollController scrollController;

  static const int _columns = 5;
  static const double _spacing = 10.0;
  static const double _itemAspectRatio = 0.7;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        color: kColorBackDark,
        child: const Center(
          child: CircularProgressIndicator(color: kColorPrimary),
        ),
      );
    }

    if (movies.isEmpty) {
      return Container(
        color: kColorBackDark,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FontAwesomeIcons.film, size: 48, color: kColorHint),
              const SizedBox(height: 14),
              Text(
                'No movies found',
                style: Get.textTheme.bodyMedium!.copyWith(color: kColorHint),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: kColorBackDark,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        controller: scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
          childAspectRatio: _itemAspectRatio,
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          final isSelected = index == selectedIdx;
          final isItemFocused = isSelected && isGridFocused;

          return _MovieGridItem(
            movie: movie,
            isSelected: isSelected,
            isHighlighted: isItemFocused,
            onTap: () => onMovieTap(movie, index),
          );
        },
      ),
    );
  }
}

class _MovieGridItem extends StatelessWidget {
  const _MovieGridItem({
    required this.movie,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
  });

  final ChannelMovie movie;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: kColorCardLight,
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
                    color: kColorFocus.withValues(alpha: .4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: movie.streamIcon ?? '',
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: kColorCardDark,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: kColorPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: kColorCardDark,
                  child: const Center(
                    child: Icon(
                      FontAwesomeIcons.film,
                      color: kColorHint,
                      size: 32,
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        kColorPrimary.withValues(alpha: .8),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    movie.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (isHighlighted)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: kColorFocus,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      FontAwesomeIcons.play,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
