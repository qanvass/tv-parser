import 'package:flutter/material.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';

import 'live_hero_preview_controller.dart';
import 'live_preview_trace.dart';

/// Full-bleed muted VLC surface. Never steals D-pad focus.
class LiveHeroPreviewSurface extends StatefulWidget {
  final LiveHeroPreviewController preview;

  const LiveHeroPreviewSurface({super.key, required this.preview});

  @override
  State<LiveHeroPreviewSurface> createState() => _LiveHeroPreviewSurfaceState();
}

class _LiveHeroPreviewSurfaceState extends State<LiveHeroPreviewSurface> {
  Size? _lastConstraints;
  bool _vlcInserted = false;

  @override
  void initState() {
    super.initState();
    LivePreviewTrace.log('surface_mounted', 'hasPlayer=${widget.preview.player != null}');
  }

  @override
  void dispose() {
    LivePreviewTrace.log(
      'surface_disposed',
      'vlcInserted=$_vlcInserted last=${_lastConstraints?.width.toInt() ?? 0}x${_lastConstraints?.height.toInt() ?? 0}',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.preview,
      builder: (context, _) {
        final player = widget.preview.player;
        if (player == null) {
          if (_vlcInserted) {
            _vlcInserted = false;
            LivePreviewTrace.log('vlc_player_removed', '');
          }
          return const SizedBox.shrink();
        }
        return ExcludeFocus(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: widget.preview.hasFirstFrame ? 1 : 0,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  if (_lastConstraints != size) {
                    _lastConstraints = size;
                    LivePreviewTrace.log(
                      'surface_constraints',
                      '${size.width.toInt()}x${size.height.toInt()} '
                      'hasFirstFrame=${widget.preview.hasFirstFrame} '
                      'opacity=${widget.preview.hasFirstFrame ? 1 : 0}',
                    );
                  }
                  if (!_vlcInserted) {
                    _vlcInserted = true;
                    LivePreviewTrace.log(
                      'vlc_player_inserted',
                      'constraints=${size.width.toInt()}x${size.height.toInt()}',
                    );
                  }
                  final aspect = player.value.aspectRatio == 0
                      ? 16 / 9
                      : player.value.aspectRatio;
                  return FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxWidth / aspect,
                      child: VlcPlayer(
                        key: widget.preview.playerKey,
                        controller: player,
                        aspectRatio: aspect,
                        placeholder: const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
