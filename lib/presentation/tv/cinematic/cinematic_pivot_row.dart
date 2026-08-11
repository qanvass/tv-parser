import 'package:flutter/material.dart';

import '../widgets/tv_channel_grid.dart';
import 'cinematic_poster_card.dart';
import 'cinematic_tokens.dart';

/// Horizontal shelf. Focused poster holds a stable X; the row translates.
class CinematicPivotRow extends StatefulWidget {
  final String title;
  final List<TvStreamRecord> streams;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const CinematicPivotRow({
    super.key,
    required this.title,
    required this.streams,
    required this.onChannelSelected,
    this.onStreamFocused,
  });

  @override
  State<CinematicPivotRow> createState() => _CinematicPivotRowState();
}

class _CinematicPivotRowState extends State<CinematicPivotRow> {
  final ScrollController _controller = ScrollController();

  static const double _gap = 12;
  static const double _pivotX = 16;
  static const double _stride = CinematicPosterCard.width + _gap;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pivotTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      final target = (index * _stride - _pivotX).clamp(0.0, max);
      _controller.animateTo(
        target,
        duration: CinematicMotion.focus,
        curve: CinematicMotion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streams.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 286,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CinematicTokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 4,
                right: 24,
                top: 10,
                bottom: 6,
              ),
              itemCount: widget.streams.length,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, index) {
                final stream = widget.streams[index];
                final key = stream.streamId ??
                    stream.enrichmentKey ??
                    '${widget.title}_$index';
                return CinematicPosterCard(
                  key: ValueKey(key),
                  stream: stream,
                  onSelected: () =>
                      widget.onChannelSelected(stream.streamUrl),
                  onFocused: (s) {
                    _pivotTo(index);
                    widget.onStreamFocused?.call(s);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
