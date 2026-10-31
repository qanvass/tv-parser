import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/cubits/favorites/favorites_cubit.dart';
import '../../../logic/cubits/watch/watching_cubit.dart';
import '../../../repository/models/channel_serie.dart';
import '../../../repository/provider/tmdb_enrichment_worker.dart';
import '../widgets/tv_channel_grid.dart';
import 'cinematic_artwork.dart';
import 'cinematic_episode_card.dart';
import 'cinematic_hero.dart';
import 'cinematic_pivot_row.dart';
import 'cinematic_prefs.dart';
import 'cinematic_tokens.dart';
import 'hero_preview_controller.dart';

/// Series presentation only. Consumes already-built rails — no 100k scan.
class CinematicSeriesPage extends StatefulWidget {
  final List<TvChannelRow> rows;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;
  final ValueChanged<TvStreamRecord>? onCardNearView;
  final List<String> categoryChips;
  final String? selectedCategory;
  final ValueChanged<String?>? onCategorySelected;

  const CinematicSeriesPage({
    super.key,
    required this.rows,
    required this.onChannelSelected,
    this.onStreamFocused,
    this.onCardNearView,
    this.categoryChips = const [],
    this.selectedCategory,
    this.onCategorySelected,
  });

  @override
  State<CinematicSeriesPage> createState() => _CinematicSeriesPageState();
}

class _NoopSeriesListenable extends Listenable {
  const _NoopSeriesListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _CinematicSeriesPageState extends State<CinematicSeriesPage> {
  static const Listenable _noopListenable = _NoopSeriesListenable();
  late final HeroPreviewController _preview;
  late final ValueNotifier<TvStreamRecord?> _heroStream;
  TvStreamRecord? _focused;

  /// Show whose episode shelf stays up. Focusing an episode must not clear it.
  TvStreamRecord? _episodeShow;
  Listenable? _focusedKeyListenable;
  List<TvChannelRow>? _indexedRows;
  Map<String, TvStreamRecord>? _seriesById;

  @override
  void initState() {
    super.initState();
    _preview = HeroPreviewController();
    _focused = _firstStream(widget.rows);
    _heroStream = ValueNotifier(_focused);
    if ((_focused?.groupedEpisodes.length ?? 0) > 1) {
      _episodeShow = _focused;
    }
    _bindFocusedKeyListener(_focused);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focused != null) _pushHero(_focused!);
    });
  }

  void _bindFocusedKeyListener(TvStreamRecord? rec) {
    _focusedKeyListenable?.removeListener(_onFocusedEnrichment);
    final key = rec?.enrichmentKey;
    if (key != null && key.isNotEmpty) {
      final l = TmdbEnrichmentWorker.instance.notifierFor(key);
      l.addListener(_onFocusedEnrichment);
      _focusedKeyListenable = l;
    } else {
      _focusedKeyListenable = null;
    }
  }

  void _onFocusedEnrichment() {
    if (!mounted || _focused == null) return;
    _pushHero(_focused!);
  }

  @override
  void didUpdateWidget(CinematicSeriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _episodeShow = null;
      _indexedRows = null;
    }
    if (!identical(widget.rows, _indexedRows)) _indexedRows = null;
    if (_focused == null && widget.rows.isNotEmpty) {
      _focused = _firstStream(widget.rows);
      _heroStream.value = _focused;
      _bindFocusedKeyListener(_focused);
      if (_focused != null) _pushHero(_focused!);
    }
  }

  @override
  void dispose() {
    _focusedKeyListenable?.removeListener(_onFocusedEnrichment);
    _heroStream.dispose();
    _preview.dispose();
    super.dispose();
  }

  static TvStreamRecord? _firstStream(List<TvChannelRow> rows) {
    for (final row in rows) {
      if (row.streams.isNotEmpty) return row.streams.first;
    }
    return null;
  }

  void _onFocused(TvStreamRecord stream) {
    if (!mounted) return;
    final changed = !identical(_focused, stream);
    _focused = stream;
    _heroStream.value = stream;
    if (changed) _bindFocusedKeyListener(stream);
    widget.onStreamFocused?.call(stream);
    _pushHero(stream);
    if (stream.groupedEpisodes.length > 1 &&
        !identical(_episodeShow, stream)) {
      setState(() => _episodeShow = stream);
    }
  }

  void _pushHero(TvStreamRecord stream) {
    final extra = stream.enrichmentKey == null
        ? null
        : TmdbEnrichmentWorker.instance.lookup(stream.enrichmentKey!);
    _preview.onFocusChanged(
      key: stream.enrichmentKey ?? stream.streamId ?? stream.streamUrl,
      art: CinematicArtwork.fromRecord(stream, extra: extra),
      mode: CinematicPrefs.mode(),
      lowPower: cinematicLowPower(context),
    );
  }

  Map<String, TvStreamRecord> _catalogById() {
    if (identical(_indexedRows, widget.rows) && _seriesById != null) {
      return _seriesById!;
    }
    final byId = <String, TvStreamRecord>{};
    for (final row in widget.rows) {
      for (final s in row.streams) {
        final id = s.streamId;
        if (id != null && id.isNotEmpty) byId[id] = s;
      }
    }
    _indexedRows = widget.rows;
    _seriesById = byId;
    return byId;
  }

  List<TvStreamRecord> _continueWatching(WatchingState watch) {
    if (watch.series.isEmpty) return const [];
    final byId = _catalogById();
    final out = <TvStreamRecord>[];
    for (final w in watch.series.take(12)) {
      final matched = byId[w.streamId];
      final progress = w.durationStrm > 0
          ? (w.sliderValue / w.durationStrm).clamp(0.0, 1.0)
          : null;
      if (matched != null) {
        out.add(matched.copyWith(watchProgress: progress));
      } else {
        out.add(
          TvStreamRecord(
            title: w.title,
            subtitle: 'Resume',
            streamUrl: w.stream.isNotEmpty ? w.stream : w.streamId,
            imageUrl: w.image.isNotEmpty ? w.image : null,
            streamId: w.streamId,
            posterStyle: TvPosterStyle.vodPortrait,
            watchProgress: progress,
          ),
        );
      }
    }
    return out;
  }

  bool _inMyList(FavoritesState favs, TvStreamRecord? rec) {
    final id = rec?.streamId;
    if (id == null || id.isEmpty) return false;
    return favs.series.any((s) => s.seriesId == id);
  }

  void _toggleMyList(TvStreamRecord rec) {
    final cubit = context.read<FavoritesCubit>();
    final id = rec.streamId;
    if (id == null || id.isEmpty) return;
    final existing = cubit.state.series.where((s) => s.seriesId == id);
    cubit.addSerie(
      ChannelSerie(
        name: rec.title,
        seriesId: rec.streamId,
        cover: rec.imageUrl,
        directSource: rec.streamUrl,
        plot: rec.overview,
      ),
      isAdd: existing.isEmpty,
    );
    setState(() {});
  }

  CinematicSelectedMovie? _selectedOf(TvStreamRecord? rec) {
    if (rec == null) return null;
    final extra = rec.enrichmentKey == null
        ? null
        : TmdbEnrichmentWorker.instance.lookup(rec.enrichmentKey!);
    return CinematicSelectedMovie(
      stream: rec,
      art: CinematicArtwork.fromRecord(rec, extra: extra),
      extra: extra,
    );
  }

  String _rowShelfKey(TvChannelRow row) {
    final id = row.streams.isEmpty
        ? ''
        : (row.streams.first.streamId ?? row.streams.first.title);
    return 'shelf-row-${row.title}-$id';
  }

  int? _shelfIndex(
    Key key, {
    required bool hasEpisodes,
    required bool hasContinue,
    required List<TvChannelRow> rows,
  }) {
    if (key is! ValueKey<String>) return null;
    final id = key.value;
    var index = 0;
    if (hasEpisodes) {
      if (id == 'shelf-episodes') return index;
      index++;
    }
    if (hasContinue) {
      if (id == 'shelf-continue') return index;
      index++;
    }
    for (var i = 0; i < rows.length; i++) {
      if (id == _rowShelfKey(rows[i])) return index + i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<WatchingCubit>().state;
    final continueItems = _continueWatching(watch);
    final show = _episodeShow;
    final episodes = show?.groupedEpisodes ?? const <TvStreamRecord>[];
    final hasEpisodes = episodes.length > 1;
    final hasContinue = continueItems.isNotEmpty;
    final nonEmptyRows = widget.rows
        .where((r) => r.streams.isNotEmpty)
        .toList(growable: false);
    final prefixCount = (hasEpisodes ? 1 : 0) + (hasContinue ? 1 : 0);
    final totalShelves = prefixCount + nonEmptyRows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ValueListenableBuilder<TvStreamRecord?>(
            valueListenable: _heroStream,
            builder: (context, stream, _) {
              return BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, favs) {
                  final extra = stream?.enrichmentKey == null
                      ? _noopListenable
                      : TmdbEnrichmentWorker.instance.notifierFor(
                          stream!.enrichmentKey!,
                        );
                  return ListenableBuilder(
                    listenable: extra,
                    builder: (context, _) {
                      final selected = _selectedOf(stream);
                      return CinematicHero(
                        selected: selected,
                        preview: _preview,
                        kenBurns: !cinematicLowPower(context),
                        eyebrow: 'SERIES',
                        onWatch:
                            selected == null ||
                                selected.stream.streamUrl.isEmpty
                            ? null
                            : () => widget.onChannelSelected(
                                selected.stream.streamUrl,
                              ),
                        onMyList: selected == null
                            ? null
                            : () => _toggleMyList(selected.stream),
                        inMyList: _inMyList(favs, stream),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (widget.categoryChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SeriesChips(
            labels: widget.categoryChips,
            selected: widget.selectedCategory,
            onSelected: widget.onCategorySelected,
          ),
        ],
        Expanded(
          flex: 6,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 28),
            cacheExtent: 520,
            itemCount: totalShelves,
            findChildIndexCallback: (key) => _shelfIndex(
              key,
              hasEpisodes: hasEpisodes,
              hasContinue: hasContinue,
              rows: nonEmptyRows,
            ),
            itemBuilder: (context, index) {
              var cursor = index;
              if (hasEpisodes) {
                if (cursor == 0) {
                  return Padding(
                    key: const ValueKey('shelf-episodes'),
                    padding: const EdgeInsets.only(bottom: 18),
                    child: CinematicEpisodeRow(
                      title: 'Episodes · ${show!.title}',
                      streams: episodes.take(24).toList(growable: false),
                      onChannelSelected: widget.onChannelSelected,
                      onStreamFocused: _onFocused,
                      onCardNearView: widget.onCardNearView,
                    ),
                  );
                }
                cursor--;
              }
              if (hasContinue) {
                if (cursor == 0) {
                  return Padding(
                    key: const ValueKey('shelf-continue'),
                    padding: const EdgeInsets.only(bottom: 18),
                    child: CinematicPivotRow(
                      title: 'Continue Watching',
                      streams: continueItems,
                      onChannelSelected: widget.onChannelSelected,
                      onStreamFocused: _onFocused,
                      onCardNearView: widget.onCardNearView,
                    ),
                  );
                }
                cursor--;
              }
              final row = nonEmptyRows[cursor];
              return Padding(
                key: ValueKey(_rowShelfKey(row)),
                padding: const EdgeInsets.only(bottom: 18),
                child: CinematicPivotRow(
                  title: row.title,
                  streams: row.streams,
                  onChannelSelected: widget.onChannelSelected,
                  onStreamFocused: _onFocused,
                  onCardNearView: widget.onCardNearView,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeriesChips extends StatelessWidget {
  final List<String> labels;
  final String? selected;
  final ValueChanged<String?>? onSelected;

  const _SeriesChips({
    required this.labels,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final values = <String?>[null, ...labels];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final on = selected == value;
          return Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter) {
                onSelected?.call(value);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                final moved = node.focusInDirection(TraversalDirection.down);
                if (moved) return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (context) {
                final focused = Focus.of(context).hasFocus;
                return GestureDetector(
                  onTap: () => onSelected?.call(value),
                  child: AnimatedContainer(
                    duration: CinematicMotion.focus,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        CinematicTokens.radiusChip,
                      ),
                      color: focused || on
                          ? CinematicTokens.glassFillStrong
                          : Colors.transparent,
                      border: Border.all(
                        color: focused
                            ? CinematicTokens.focus
                            : CinematicTokens.glassBorder,
                      ),
                    ),
                    child: Text(
                      value ?? 'All',
                      style: TextStyle(
                        color: focused || on
                            ? CinematicTokens.textPrimary
                            : CinematicTokens.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
