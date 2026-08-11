import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../helpers/helpers.dart';
import '../../../repository/api/artwork_url_resolver.dart';
import '../../../repository/epg/xmltv_repository.dart';
import '../../../repository/provider/tmdb_enrichment_worker.dart';
import '../../widgets/smart_channel_logo.dart';
import 'tv_artwork_shimmer.dart';
import 'tv_branded_empty.dart';
import 'tv_epg_peek.dart';

enum TvPosterStyle { liveLandscape, vodPortrait }

const Object _keep = Object();

class TvStreamRecord {
  final String title;
  final String subtitle;
  final String streamUrl;
  final String? imageUrl;
  /// Live channel number, or S1:E1 when parsed. Never a raw 001 VOD index.
  final String? badge;
  final bool isHd;
  final String? tvgId;
  /// Validated IMDb title id when the catalog row had one. Never the title.
  final String? imdbId;
  final String? streamId;
  final String? backdropUrl;
  final TvPosterStyle posterStyle;
  final int? year;
  final double? rating;
  final int? runtimeMinutes;
  final int? season;
  final int? episode;
  final String? qualityLabel;
  final String? overview;
  final String? trailerUrl;
  final double? watchProgress;
  final String? enrichmentKey;
  final List<TvStreamRecord> groupedEpisodes;
  /// Provider taxonomy — not a UI heading. Never overwrite the catalog name.
  final String? providerCategoryId;
  final String? providerCategoryName;

  const TvStreamRecord({
    required this.title,
    required this.subtitle,
    required this.streamUrl,
    this.imageUrl,
    this.badge,
    this.isHd = false,
    this.tvgId,
    this.imdbId,
    this.streamId,
    this.backdropUrl,
    this.posterStyle = TvPosterStyle.liveLandscape,
    this.year,
    this.rating,
    this.runtimeMinutes,
    this.season,
    this.episode,
    this.qualityLabel,
    this.overview,
    this.trailerUrl,
    this.watchProgress,
    this.enrichmentKey,
    this.groupedEpisodes = const [],
    this.providerCategoryId,
    this.providerCategoryName,
  });

  bool get isVod => posterStyle == TvPosterStyle.vodPortrait;

  TvStreamRecord copyWith({
    String? title,
    String? subtitle,
    String? streamUrl,
    Object? imageUrl = _keep,
    Object? badge = _keep,
    bool? isHd,
    Object? tvgId = _keep,
    Object? imdbId = _keep,
    Object? streamId = _keep,
    Object? backdropUrl = _keep,
    TvPosterStyle? posterStyle,
    Object? year = _keep,
    Object? rating = _keep,
    Object? runtimeMinutes = _keep,
    Object? season = _keep,
    Object? episode = _keep,
    Object? qualityLabel = _keep,
    Object? overview = _keep,
    Object? trailerUrl = _keep,
    Object? watchProgress = _keep,
    Object? enrichmentKey = _keep,
    List<TvStreamRecord>? groupedEpisodes,
    Object? providerCategoryId = _keep,
    Object? providerCategoryName = _keep,
  }) {
    return TvStreamRecord(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      streamUrl: streamUrl ?? this.streamUrl,
      imageUrl: identical(imageUrl, _keep) ? this.imageUrl : imageUrl as String?,
      badge: identical(badge, _keep) ? this.badge : badge as String?,
      isHd: isHd ?? this.isHd,
      tvgId: identical(tvgId, _keep) ? this.tvgId : tvgId as String?,
      imdbId: identical(imdbId, _keep) ? this.imdbId : imdbId as String?,
      streamId: identical(streamId, _keep) ? this.streamId : streamId as String?,
      backdropUrl: identical(backdropUrl, _keep)
          ? this.backdropUrl
          : backdropUrl as String?,
      posterStyle: posterStyle ?? this.posterStyle,
      year: identical(year, _keep) ? this.year : year as int?,
      rating: identical(rating, _keep) ? this.rating : rating as double?,
      runtimeMinutes: identical(runtimeMinutes, _keep)
          ? this.runtimeMinutes
          : runtimeMinutes as int?,
      season: identical(season, _keep) ? this.season : season as int?,
      episode: identical(episode, _keep) ? this.episode : episode as int?,
      qualityLabel: identical(qualityLabel, _keep)
          ? this.qualityLabel
          : qualityLabel as String?,
      overview: identical(overview, _keep) ? this.overview : overview as String?,
      trailerUrl:
          identical(trailerUrl, _keep) ? this.trailerUrl : trailerUrl as String?,
      watchProgress: identical(watchProgress, _keep)
          ? this.watchProgress
          : watchProgress as double?,
      enrichmentKey: identical(enrichmentKey, _keep)
          ? this.enrichmentKey
          : enrichmentKey as String?,
      groupedEpisodes: groupedEpisodes ?? this.groupedEpisodes,
      providerCategoryId: identical(providerCategoryId, _keep)
          ? this.providerCategoryId
          : providerCategoryId as String?,
      providerCategoryName: identical(providerCategoryName, _keep)
          ? this.providerCategoryName
          : providerCategoryName as String?,
    );
  }
}

class TvChannelRow {
  final String title;
  final List<TvStreamRecord> streams;

  const TvChannelRow({required this.title, required this.streams});
}

/// Shared section header for category / home rails (template: compact label + View All).
class TvRailSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final IconData? icon;
  final Color? accent;

  const TvRailSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? kColorPrimary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: bar, size: 18),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Split Live/VOD hero: text + progress on the left, ClearLogo / poster on the right.
class TvLiveFocusHero extends StatelessWidget {
  final TvStreamRecord? stream;
  final VoidCallback? onWatch;
  final VoidCallback? onTrailer;
  final bool focusedCta;
  final String? kicker;

  const TvLiveFocusHero({
    super.key,
    this.stream,
    this.onWatch,
    this.onTrailer,
    this.focusedCta = false,
    this.kicker,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        XmlTvRepository.instance,
        TmdbEnrichmentWorker.instance,
      ]),
      builder: (context, _) => _buildHero(context),
    );
  }

  Widget _buildHero(BuildContext context) {
    final active = stream;
    final extra = active?.enrichmentKey == null
        ? null
        : TmdbEnrichmentWorker.instance.lookup(active!.enrichmentKey!);
    final hasChannel = active != null && active.title.isNotEmpty;
    final epg = (hasChannel && !active.isVod)
        ? XmlTvRepository.instance.nowNext(
            tvgId: active.tvgId,
            channelName: active.title,
            streamId: active.streamId,
          )
        : null;
    final programmeTitle = epg?.now.title;
    final hasProgramme =
        programmeTitle != null && programmeTitle.trim().isNotEmpty;
    final rec = hasChannel ? active : null;
    final year = extra?.year ?? rec?.year;
    final rating = extra?.rating ?? rec?.rating;
    final runtime = extra?.runtimeMinutes ?? rec?.runtimeMinutes;
    final overview = extra?.overview ?? rec?.overview;
    final trailer = extra?.trailerUrl ?? rec?.trailerUrl;
    final poster = extra?.posterUrl ?? rec?.imageUrl;
    final kickerText = kicker ??
        (hasProgramme
            ? 'ON NOW'
            : (rec?.isVod == true ? 'SPOTLIGHT' : 'LIVE TV'));
    final primaryTitle = hasProgramme
        ? programmeTitle
        : (rec?.title ?? 'Browse your playlist');
    final metaBits = <String>[
      if (hasProgramme) rec!.title,
      if (rec != null &&
          !rec.isVod &&
          rec.badge != null &&
          rec.badge!.isNotEmpty)
        'Ch ${rec.badge}',
      if (year != null) '$year',
      if (runtime != null && runtime > 0) '${runtime}m',
      if (rating != null && rating > 0) rating.toStringAsFixed(1),
      if (rec?.qualityLabel != null) rec!.qualityLabel!,
      if (rec != null && rec.isHd && rec.qualityLabel == null) 'HD',
      if (rec != null && rec.groupedEpisodes.length > 1)
        '${rec.groupedEpisodes.length} episodes',
    ];
    final secondary = rec != null
        ? metaBits.where((s) => s.isNotEmpty).join('  ·  ')
        : 'Move focus onto a channel tile to preview details';
    final times = (epg != null)
        ? '${_fmtTime(epg.now.start)} – ${_fmtTime(epg.now.stop)}'
        : null;

    final isLive = rec != null && !rec.isVod;
    return Container(
      height: rec?.isVod == true ? 292 : 286,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: kColorPrimary.withValues(alpha: 0.42),
            blurRadius: 36,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF050A18)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF050A18),
                    Color(0xE6081428),
                    Color(0x99050A18),
                    Color(0xCC050A18),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kColorPrimary,
                      kColorPrimarySoft,
                      kColorPrimary.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: kColorPrimary.withValues(alpha: 0.95)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: kColorPrimary.withValues(alpha: 0.55),
                  width: 1.6,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isLive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D2E),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x99E11D2E),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                kickerText,
                                style: TextStyle(
                                  color: kColorPrimary.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            if (isLive) ...[
                              const SizedBox(width: 10),
                              Text(
                                kickerText == 'LIVE' ? 'NOW PLAYING' : kickerText,
                                style: TextStyle(
                                  color: kColorPrimary.withValues(alpha: 0.95),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          primaryTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.7,
                          ),
                        ),
                        if (secondary.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (times != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            times,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (epg != null) ...[
                          const SizedBox(height: 10),
                          _NowProgressBar(start: epg.now.start, stop: epg.now.stop),
                        ],
                        if (rec != null &&
                            !rec.isVod &&
                            (epg == null || epg.next == null)) ...[
                          const SizedBox(height: 6),
                          TvEpgPeek(
                            streamId: rec.streamId ?? rec.streamUrl,
                            tvgId: rec.tvgId,
                            channelName: rec.title,
                            compact: true,
                          ),
                        ],
                        if (overview != null &&
                            overview.trim().isNotEmpty &&
                            rec?.isVod == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (rec != null && onWatch != null)
                          Row(
                            children: [
                              _GlassPill(
                                focused: true,
                                label: rec.isVod ? 'Watch Now' : 'Watch Now',
                                icon: Icons.play_arrow_rounded,
                              ),
                              if (onTrailer != null &&
                                  trailer != null &&
                                  trailer.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _GlassPill(
                                  focused: false,
                                  label: 'Trailer',
                                  icon: Icons.movie_outlined,
                                  muted: true,
                                ),
                              ],
                              const SizedBox(width: 12),
                              Text(
                                'OK to play',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  if (rec != null)
                    SizedBox(
                      width: rec.isVod ? 128 : 210,
                      child: rec.isVod
                          ? _VodHeroPoster(url: poster, title: rec.title)
                          : _ClearLogo(
                              url: rec.imageUrl,
                              name: rec.title,
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime utc) {
    final l = utc.toLocal();
    final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final mer = l.hour >= 12 ? 'PM' : 'AM';
    final min = l.minute.toString().padLeft(2, '0');
    return '$hour:$min $mer';
  }
}

class _NowProgressBar extends StatelessWidget {
  final DateTime start;
  final DateTime stop;

  const _NowProgressBar({required this.start, required this.stop});

  @override
  Widget build(BuildContext context) {
    final total = stop.difference(start).inMilliseconds;
    if (total <= 0) return const SizedBox.shrink();
    final now = DateTime.now().toUtc();
    final p = (now.difference(start.toUtc()).inMilliseconds / total)
        .clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: p,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        color: kColorPrimary,
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final bool focused;
  final String label;
  final IconData icon;
  final bool muted;

  const _GlassPill({
    required this.focused,
    required this.label,
    required this.icon,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: focused
                ? kColorPrimary.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: muted ? 0.06 : 0.12),
            border: Border.all(
              color: focused
                  ? kColorFocus
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: focused ? Colors.black : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: focused ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearLogo extends StatelessWidget {
  final String? url;
  final String name;

  const _ClearLogo({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (!ArtworkUrlResolver.isUsableImageUrl(url)) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: SmartChannelLogo(
        primaryUrl: url,
        channelName: name,
        fit: BoxFit.contain,
        memCacheWidth: 360,
        showInitialsFallback: false,
        placeholder: const SizedBox.shrink(),
      ),
    );
  }
}

class _VodHeroPoster extends StatelessWidget {
  final String? url;
  final String title;

  const _VodHeroPoster({this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ArtworkUrlResolver.isUsableImageUrl(url)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: 280,
                placeholder: (_, __) => const TvArtworkShimmer(),
                errorWidget: (_, __, ___) => const TvPosterFallbackGradient(),
              )
            : const TvPosterFallbackGradient(),
      ),
    );
  }
}

class TvChannelGrid extends StatelessWidget {
  final List<TvChannelRow> rows;
  final ValueChanged<String> onChannelSelected;
  final Widget? header;
  final ValueChanged<TvStreamRecord>? onStreamFocused;
  final TvPosterStyle posterStyle;

  const TvChannelGrid({
    super.key,
    required this.rows,
    required this.onChannelSelected,
    this.header,
    this.onStreamFocused,
    this.posterStyle = TvPosterStyle.liveLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = header != null;

    if (rows.isEmpty && !hasHeader) {
      return const TvBrandedEmpty(
        title: 'Nothing to browse here',
        subtitle:
            'No content is available in this section for the connected playlist. Press Left for the menu, or retry from Settings.',
      );
    }

    final itemCount =
        rows.length + (hasHeader ? 1 : 0) + (rows.isEmpty && hasHeader ? 1 : 0);

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(400.0),
      padding: const EdgeInsets.only(bottom: 48),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: header!,
          );
        }

        if (rows.isEmpty && hasHeader) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: TvBrandedEmpty(
              title: 'No live categories yet',
              subtitle:
                  'This playlist has not returned live categories. Press Left for the menu, or open Settings to refresh sources.',
            ),
          );
        }

        final rowIndex = hasHeader ? index - 1 : index;
        final row = rows[rowIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: _TvStreamRow(
            row: row,
            onChannelSelected: onChannelSelected,
            onStreamFocused: onStreamFocused,
            posterStyle: posterStyle,
          ),
        );
      },
    );
  }
}

class _TvStreamRow extends StatelessWidget {
  final TvChannelRow row;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;
  final TvPosterStyle posterStyle;

  const _TvStreamRow({
    required this.row,
    required this.onChannelSelected,
    this.onStreamFocused,
    this.posterStyle = TvPosterStyle.liveLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final vod = posterStyle == TvPosterStyle.vodPortrait;
    return SizedBox(
      height: vod ? 248 : 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvRailSectionHeader(
            title: row.title,
            trailing: '${row.streams.length}',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(400.0),
              scrollDirection: Axis.horizontal,
              itemCount: row.streams.length,
              itemBuilder: (context, index) {
                final stream = row.streams[index];
                final numbered = vod
                    ? stream
                    : (stream.badge != null
                        ? stream
                        : stream.copyWith(badge: '${index + 1}'.padLeft(3, '0')));

                return Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                  child: TvChannelCard(
                    stream: numbered.copyWith(posterStyle: posterStyle),
                    onSelected: () => onChannelSelected(numbered.streamUrl),
                    onFocused: onStreamFocused,
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

class TvChannelCard extends StatefulWidget {
  final TvStreamRecord stream;
  final VoidCallback onSelected;
  final ValueChanged<TvStreamRecord>? onFocused;

  static const double tileWidth = 168;
  static const double tileHeight = 118;
  static const double posterWidth = 132;
  static const double posterHeight = 198;

  const TvChannelCard({
    super.key,
    required this.stream,
    required this.onSelected,
    this.onFocused,
  });

  @override
  State<TvChannelCard> createState() => _TvChannelCardState();
}

class _TvChannelCardState extends State<TvChannelCard> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA ||
        k == LogicalKeyboardKey.space) {
      widget.onSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final vod = widget.stream.isVod;
    return Focus(
      onFocusChange: (value) {
        setState(() {
          _focused = value;
        });
        if (value) {
          widget.onFocused?.call(widget.stream);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Scrollable.ensureVisible(
              context,
              alignment: 0.28,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            );
          });
        }
      },
      onKeyEvent: _onKey,
      child: AnimatedScale(
        scale: _focused ? (vod ? 1.08 : 1.06) : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          elevation: _focused ? 10 : 0,
          shadowColor: kColorPrimary.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            canRequestFocus: false,
            onTap: widget.onSelected,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: vod ? TvChannelCard.posterWidth : TvChannelCard.tileWidth,
              height: vod ? TvChannelCard.posterHeight : TvChannelCard.tileHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF121C2C),
                border: Border.all(
                  width: _focused ? 2.8 : 1.0,
                  color: _focused
                      ? kColorFocus
                      : Colors.white.withValues(alpha: 0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.36),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  if (_focused)
                    BoxShadow(
                      color: kColorPrimary.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 0.6,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ListenableBuilder(
                listenable: TmdbEnrichmentWorker.instance,
                builder: (context, _) {
                  final extra = widget.stream.enrichmentKey == null
                      ? null
                      : TmdbEnrichmentWorker.instance
                          .lookup(widget.stream.enrichmentKey!);
                  final image = extra?.posterUrl ?? widget.stream.imageUrl;
                  final year = extra?.year ?? widget.stream.year;
                  final rating = extra?.rating ?? widget.stream.rating;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: vod
                            ? const EdgeInsets.fromLTRB(0, 0, 0, 36)
                            : const EdgeInsets.fromLTRB(10, 26, 10, 34),
                        child: _CardArtwork(
                          imageUrl: image,
                          channelName: widget.stream.title,
                          cover: vod,
                        ),
                      ),
                      if (_visibleBadge() != null)
                        Positioned(
                          top: 7,
                          left: 7,
                          child: _MiniBadge(text: _visibleBadge()!),
                        ),
                      if (_qualityBadge(year, rating) != null)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: _MiniBadge(
                            text: _qualityBadge(year, rating)!,
                            accent: true,
                          ),
                        ),
                      if ((widget.stream.watchProgress ?? 0) > 0.02)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 34,
                          child: LinearProgressIndicator(
                            value: widget.stream.watchProgress!.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: Colors.black45,
                            color: kColorPrimary,
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                kColorBackDark.withValues(alpha: 0.92),
                                const Color(0xFF050A12),
                              ],
                            ),
                          ),
                          child: _CardCaption(stream: widget.stream),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _visibleBadge() {
    final b = widget.stream.badge;
    if (b == null || b.isEmpty) return null;
    if (widget.stream.isVod && RegExp(r'^\d{3}$').hasMatch(b)) return null;
    return b;
  }

  String? _qualityBadge(int? year, double? rating) {
    if (widget.stream.qualityLabel != null) return widget.stream.qualityLabel;
    if (widget.stream.isHd) return 'HD';
    if (widget.stream.isVod && year != null) return '$year';
    if (rating != null && rating > 0) return rating.toStringAsFixed(1);
    return null;
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final bool accent;

  const _MiniBadge({required this.text, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent
            ? kColorPrimary.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: accent
              ? kColorPrimary.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? kColorPrimary : Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CardCaption extends StatelessWidget {
  final TvStreamRecord stream;

  const _CardCaption({required this.stream});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: XmlTvRepository.instance,
      builder: (context, _) {
        final now = (!stream.isVod)
            ? XmlTvRepository.instance
                .nowNext(
                  tvgId: stream.tvgId,
                  channelName: stream.title,
                  streamId: stream.streamId,
                )
                ?.now
                .title
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stream.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            if (now != null && now.isNotEmpty)
              Text(
                now,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CardArtwork extends StatelessWidget {
  final String? imageUrl;
  final String channelName;
  final bool cover;

  const _CardArtwork({
    this.imageUrl,
    required this.channelName,
    this.cover = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorCardDark.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(cover ? 0 : 8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cover ? 0 : 8),
        child: SmartChannelLogo(
          primaryUrl: imageUrl,
          channelName: channelName,
          fit: cover ? BoxFit.cover : BoxFit.contain,
          memCacheWidth: cover ? 280 : 320,
          initialsSize: 36,
          showInitialsFallback: false,
          placeholder: cover
              ? const TvArtworkShimmer()
              : const TvArtworkShimmer(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
        ),
      ),
    );
  }
}
