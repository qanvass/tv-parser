import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../helpers/helpers.dart';

/// Live-home shortcut strip for Android TV only.
/// Switches shell tabs via callbacks — does **not** push mobile browse screens.
class TvUtilityCardsRow extends StatelessWidget {
  /// Called with shell nav index (movies / series). Live is already active.
  final ValueChanged<int>? onSwitchTab;
  final bool showLocalHint;
  final VoidCallback? onFocusLocalRail;

  const TvUtilityCardsRow({
    super.key,
    this.onSwitchTab,
    this.showLocalHint = false,
    this.onFocusLocalRail,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_UtilityEntry>[
      const _UtilityEntry(
        title: 'Live groups',
        subtitle: 'This playlist',
        icon: Icons.live_tv_rounded,
        tone: TvUtilityTone.primary,
        action: _UtilityAction.liveStay,
      ),
      if (showLocalHint)
        const _UtilityEntry(
          title: 'Local TV',
          subtitle: 'Nearby rail',
          icon: Icons.location_on_rounded,
          tone: TvUtilityTone.warm,
          action: _UtilityAction.localRail,
        ),
      const _UtilityEntry(
        title: 'Movies',
        subtitle: 'Playlist catalog',
        icon: Icons.local_movies_rounded,
        tone: TvUtilityTone.deep,
        action: _UtilityAction.moviesTab,
      ),
      const _UtilityEntry(
        title: 'Series',
        subtitle: 'Playlist catalog',
        icon: Icons.tv_rounded,
        tone: TvUtilityTone.cool,
        action: _UtilityAction.seriesTab,
      ),
    ];

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        scrollCacheExtent: const ScrollCacheExtent.pixels(200.0),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 4.0, bottom: 4.0),
            child: TvUtilityCard(
              title: item.title,
              subtitle: item.subtitle,
              icon: item.icon,
              tone: item.tone,
              onTap: () {
                switch (item.action) {
                  case _UtilityAction.liveStay:
                    break;
                  case _UtilityAction.localRail:
                    onFocusLocalRail?.call();
                    break;
                  case _UtilityAction.moviesTab:
                    onSwitchTab?.call(1);
                    break;
                  case _UtilityAction.seriesTab:
                    onSwitchTab?.call(2);
                    break;
                }
              },
            ),
          );
        },
      ),
    );
  }
}

enum TvUtilityTone { primary, cool, deep, warm }

enum _UtilityAction { liveStay, localRail, moviesTab, seriesTab }

class _UtilityEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final TvUtilityTone tone;
  final _UtilityAction action;

  const _UtilityEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.action,
  });
}

class TvUtilityCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final TvUtilityTone tone;

  const TvUtilityCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.tone = TvUtilityTone.primary,
  });

  @override
  State<TvUtilityCard> createState() => _TvUtilityCardState();
}

class _TvUtilityCardState extends State<TvUtilityCard> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA ||
        k == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<Color> get _gradient {
    switch (widget.tone) {
      case TvUtilityTone.primary:
        return const [Color(0xFF0E3A3A), Color(0xFF0A1C28)];
      case TvUtilityTone.cool:
        return const [Color(0xFF16324A), Color(0xFF0A1522)];
      case TvUtilityTone.deep:
        return const [Color(0xFF1A2A40), Color(0xFF0B121E)];
      case TvUtilityTone.warm:
        return const [Color(0xFF3A2E14), Color(0xFF1A160C)];
    }
  }

  Color get _accent {
    switch (widget.tone) {
      case TvUtilityTone.primary:
        return kColorPrimary;
      case TvUtilityTone.cool:
        return const Color(0xFF5EC8FF);
      case TvUtilityTone.deep:
        return const Color(0xFF7EB6FF);
      case TvUtilityTone.warm:
        return kColorAccentWarm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return Focus(
      onFocusChange: (value) {
        setState(() {
          _focused = value;
        });
        if (value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Scrollable.ensureVisible(
              context,
              alignment: 0.4,
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
            );
          });
        }
      },
      onKeyEvent: _onKey,
      child: AnimatedScale(
        scale: _focused ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            canRequestFocus: false,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: 176,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _gradient,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focused
                      ? kColorFocus
                      : accent.withValues(alpha: 0.35),
                  width: _focused ? 2.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _focused
                        ? accent.withValues(alpha: 0.38)
                        : Colors.black.withValues(alpha: 0.28),
                    blurRadius: _focused ? 18 : 10,
                    spreadRadius: _focused ? 1 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: accent, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
