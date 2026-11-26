import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';
import '../../../repository/provider/title_normalizer.dart';

/// Title and detail for the paused lower third, from the name the player was
/// opened with. Episodes give the show and `S2 E2`; movies give the name and
/// year. A placeholder name gives an empty title, which hides the overlay.
({String title, String? detail}) nowWatchingLabel(String rawTitle) {
  const placeholders = {'tv stream', 'movie', 'episode', 'tv parser'};
  final raw = rawTitle.trim();
  if (raw.isEmpty || placeholders.contains(raw.toLowerCase())) {
    return (title: '', detail: null);
  }
  final t = TitleNormalizer.parse(raw);
  if (t.season != null && t.episode != null) {
    return (title: t.displayTitle, detail: 'S${t.season} E${t.episode}');
  }
  return (title: t.displayTitle, detail: t.year?.toString());
}

/// Lower-left "NOW WATCHING" title shown while playback is paused.
///
/// Display only: it is told whether the player is paused and what is playing,
/// and never touches the player. The entrance runs once each time [visible]
/// turns true and reverses when it turns false.
class NowWatchingLowerThird extends StatefulWidget {
  const NowWatchingLowerThird({
    super.key,
    required this.visible,
    required this.title,
    this.detail,
    this.bottom = 150,
    this.left = 36,
  });

  final bool visible;

  /// Programme name: the series, movie or channel being played.
  final String title;

  /// Extra identifier such as `S2 E2`. Null or empty shows the title alone.
  final String? detail;
  final double bottom;
  final double left;

  @override
  State<NowWatchingLowerThird> createState() => _NowWatchingLowerThirdState();
}

class _NowWatchingLowerThirdState extends State<NowWatchingLowerThird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
    value: widget.visible ? 1 : 0,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(-0.06, 0.10),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void didUpdateWidget(NowWatchingLowerThird oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim();
    if (title.isEmpty) return const SizedBox.shrink();
    final detail = widget.detail?.trim() ?? '';
    final maxWidth = MediaQuery.sizeOf(context).width * 0.6;
    return Positioned(
      left: widget.left,
      bottom: widget.bottom,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            if (_anim.isDismissed) return const SizedBox.shrink();
            return FadeTransition(
              opacity: _fade,
              child: SlideTransition(position: _slide, child: child),
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xD9071226),
                    Color(0x99071226),
                    Color(0x00071226),
                  ],
                  stops: [0.0, 0.7, 1.0],
                ),
                border: Border(
                  left: BorderSide(color: kColorPrimary, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 56, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOW WATCHING',
                      style: TextStyle(
                        color: Color(0xFFB4C0D4),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: title),
                          if (detail.isNotEmpty)
                            TextSpan(
                              text: '  •  $detail',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kColorPrimary, Color(0x0000A3FF)],
                        ),
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
}

/// Centre "Paused" mark. Fades with [visible]; display only.
class PausedIndicator extends StatelessWidget {
  const PausedIndicator({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xB3071226),
                    border: Border.all(color: kColorPrimary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: kColorPrimary.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paused',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
