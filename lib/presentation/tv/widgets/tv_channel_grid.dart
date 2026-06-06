import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TvStreamRecord {
  final String title;
  final String subtitle;
  final String streamUrl;
  final String? imageUrl;

  const TvStreamRecord({
    required this.title,
    required this.subtitle,
    required this.streamUrl,
    this.imageUrl,
  });
}

class TvChannelRow {
  final String title;
  final List<TvStreamRecord> streams;

  const TvChannelRow({
    required this.title,
    required this.streams,
  });
}

class TvChannelGrid extends StatelessWidget {
  final List<TvChannelRow> rows;
  final ValueChanged<String> onChannelSelected;
  final Widget? header;

  const TvChannelGrid({
    super.key,
    required this.rows,
    required this.onChannelSelected,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = header != null;

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: rows.length + (hasHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 34),
            child: header!,
          );
        }

        final rowIndex = hasHeader ? index - 1 : index;
        final row = rows[rowIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: 34),
          child: _TvStreamRow(
            row: row,
            onChannelSelected: onChannelSelected,
          ),
        );
      },
    );
  }
}

class _TvStreamRow extends StatelessWidget {
  final TvChannelRow row;
  final ValueChanged<String> onChannelSelected;

  const _TvStreamRow({
    required this.row,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
              scrollDirection: Axis.horizontal,
              itemCount: row.streams.length,
              itemBuilder: (context, index) {
                final stream = row.streams[index];

                return Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: TvChannelCard(
                    stream: stream,
                    onSelected: () => onChannelSelected(stream.streamUrl),
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

  const TvChannelCard({
    super.key,
    required this.stream,
    required this.onSelected,
  });

  @override
  State<TvChannelCard> createState() => _TvChannelCardState();
}

class _TvChannelCardState extends State<TvChannelCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) {
        setState(() {
          _focused = value;
        });
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onSelected,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  width: _focused ? 2.5 : 1.0,
                  color: _focused
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  if (_focused)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CardArtwork(imageUrl: widget.stream.imageUrl),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stream.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stream.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: AnimatedOpacity(
                      opacity: _focused ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
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
}

class _CardArtwork extends StatelessWidget {
  final String? imageUrl;

  const _CardArtwork({
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 300,
        placeholder: (context, url) => const _FallbackArtwork(),
        errorWidget: (context, url, error) => const _FallbackArtwork(),
      );
    }

    return const _FallbackArtwork();
  }
}

class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B0F2F),
            Color(0xFF101018),
            Color(0xFF050508),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.live_tv_rounded,
          color: Colors.white.withValues(alpha: 0.18),
          size: 62,
        ),
      ),
    );
  }
}
