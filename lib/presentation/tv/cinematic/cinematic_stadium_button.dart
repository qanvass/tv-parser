import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cinematic_tokens.dart';

/// Stadium CTA. Focused = light fill. Unfocused = dark glass.
class CinematicStadiumButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool autofocus;

  const CinematicStadiumButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.autofocus = false,
  });

  @override
  State<CinematicStadiumButton> createState() => _CinematicStadiumButtonState();
}

class _CinematicStadiumButtonState extends State<CinematicStadiumButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.gameButtonA ||
            k == LogicalKeyboardKey.space) {
          widget.onPressed?.call();
          return enabled ? KeyEventResult.handled : KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.04 : 1.0,
        duration: CinematicMotion.focus,
        curve: CinematicMotion.standard,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(CinematicTokens.radiusStadium),
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: CinematicMotion.focus,
              curve: CinematicMotion.standard,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(CinematicTokens.radiusStadium),
                color: _focused
                    ? CinematicTokens.accent
                    : CinematicTokens.glassFill,
                border: Border.all(
                  color: _focused
                      ? CinematicTokens.focus
                      : CinematicTokens.glassBorder,
                  width: _focused ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: _focused
                        ? CinematicTokens.background
                        : CinematicTokens.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: _focused
                          ? CinematicTokens.background
                          : CinematicTokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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
