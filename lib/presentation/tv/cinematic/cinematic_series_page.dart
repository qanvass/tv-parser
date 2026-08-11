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
  final List<String> categoryChips;
  final String? selectedCategory;
  final ValueChanged<String?>? onCategorySelected;

  const CinematicSeriesPage({
    super.key,
    required this.rows,
    required this.onChannelSelected,
    this.onStreamFocused,
    this.categoryChips = const [],
    this.selectedCategory,
    this.onCategorySelected,
  });

  @override
  State<CinematicSeriesPage> createState() => _CinematicSeriesPageState();
}

class _CinematicSeriesPageState extends State<CinematicSeriesPage> {
  late final HeroPreviewController _preview;
  TvStreamRecord? _focused;

  @override
  void initState() {
    super.initState();
    _preview = HeroPreviewController();
    _focused = _firstStream(widget.rows);
    TmdbEnrichmentWorker.instance.addListener(_onEnrichment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focused != null) _pushHero(_focused!);
    });
  }

  void _onEnrichment() {
    if (!mounted || _focused == null) return;
    _pushHero(_focused!);
    setState(() {});
  }

  @override
  void didUpdateWidget(CinematicSeriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focused == null && widget.rows.isNotEmpty) {
      _focused = _firstStream(widget.rows);
      if (_focused != null) _pushHero(_focused!);
    }
  }

  @override
  void dispose() {
    TmdbEnrichmentWorker.instance.removeListener(_onEnrichment);
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
    setState(() => _focused = stream);
    widget.onStreamFocused?.call(stream);
    _pushHero(stream);
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

  List<TvStreamRecord> _continueWatching(WatchingState watch) {
    if (watch.series.isEmpty) return const [];
    final byId = <String, TvStreamRecord>{};
    for (final row in widget.rows) {
      for (final s in row.streams) {
        final id = s.streamId;
        if (id != null && id.isNotEmpty) byId[id] = s;
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<WatchingCubit>().state;
    final favs = context.watch<FavoritesCubit>().state;
    final continueItems = _continueWatching(watch);
    final inList = _inMyList(favs, _focused);
    final episodes = _focused?.groupedEpisodes ?? const <TvStreamRecord>[];

    return ListenableBuilder(
      listenable: TmdbEnrichmentWorker.instance,
      builder: (context, _) {
        final selected = _selectedOf(_focused);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: CinematicHero(
                selected: selected,
                preview: _preview,
                kenBurns: !cinematicLowPower(context),
                eyebrow: 'SERIES',
                onWatch: selected == null ||
                        selected.stream.streamUrl.isEmpty
                    ? null
                    : () => widget.onChannelSelected(selected.stream.streamUrl),
                onMyList: selected == null
                    ? null
                    : () => _toggleMyList(selected.stream),
                inMyList: inList,
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
              child: ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 28),
                children: [
                  if (episodes.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: CinematicEpisodeRow(
                        title: 'Episodes',
                        streams: episodes.take(24).toList(growable: false),
                        onChannelSelected: widget.onChannelSelected,
                        onStreamFocused: _onFocused,
                      ),
                    ),
                  if (continueItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: CinematicPivotRow(
                        title: 'Continue Watching',
                        streams: continueItems,
                        onChannelSelected: widget.onChannelSelected,
                        onStreamFocused: _onFocused,
                      ),
                    ),
                  for (final row in widget.rows)
                    if (row.streams.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: CinematicPivotRow(
                          title: row.title,
                          streams: row.streams,
                          onChannelSelected: widget.onChannelSelected,
                          onStreamFocused: _onFocused,
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
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
                      borderRadius:
                          BorderRadius.circular(CinematicTokens.radiusChip),
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
