import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../helpers/helpers.dart';

class TvNavigationItem {
  final String label;
  final IconData icon;
  final bool isUtility;

  const TvNavigationItem({
    required this.label,
    required this.icon,
    this.isUtility = false,
  });
}

class TvNavigationRail extends StatelessWidget {
  final List<TvNavigationItem> items;
  final List<TvNavigationItem> utilityItems;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onUtilitySelected;
  final List<FocusNode>? focusNodes;
  final List<FocusNode>? utilityFocusNodes;
  final bool collapsed;

  const TvNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.utilityItems = const [],
    this.onUtilitySelected,
    this.focusNodes,
    this.utilityFocusNodes,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 92.0 : 236.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xD6050A18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: kColorPrimary.withValues(alpha: 0.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: kColorPrimary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 10 : 18,
              4,
              collapsed ? 10 : 18,
              16,
            ),
            child: collapsed
                ? Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [kColorPrimaryDark, kColorPrimary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kColorPrimary.withValues(alpha: 0.35),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tv_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kColorPrimaryDark, kColorPrimary],
                          ),
                        ),
                        child: const Icon(
                          Icons.tv_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TV Parser',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Media Player',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kColorPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          // Non-scrolling column so all primary destinations stay visible
          // on 1080p TV (Search / Favorites / History must not clip).
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: _TvNavigationButton(
                        item: items[index],
                        selected: selectedIndex == index,
                        collapsed: collapsed,
                        compact: true,
                        focusNode:
                            focusNodes != null && index < focusNodes!.length
                                ? focusNodes![index]
                                : null,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (utilityItems.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 16 : 22,
                vertical: 6,
              ),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  for (var i = 0; i < utilityItems.length; i++)
                    _TvNavigationButton(
                      item: utilityItems[i],
                      selected: false,
                      collapsed: collapsed,
                      compact: true,
                      focusNode:
                          utilityFocusNodes != null &&
                              i < utilityFocusNodes!.length
                          ? utilityFocusNodes![i]
                          : null,
                      onTap: () => onUtilitySelected?.call(i),
                    ),
                ],
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

class _TvNavigationButton extends StatefulWidget {
  final TvNavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool collapsed;
  final bool compact;

  const _TvNavigationButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.focusNode,
    this.collapsed = false,
    this.compact = false,
  });

  @override
  State<_TvNavigationButton> createState() => _TvNavigationButtonState();
}

class _TvNavigationButtonState extends State<_TvNavigationButton> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = _focused;
    final bool selected = widget.selected;
    final bool lit = selected || focused;
    final vPad = widget.compact ? 8.0 : 15.0;
    final iconSize = widget.compact ? 22.0 : 24.0;
    final fontSize = widget.compact ? 15.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 4 : 10),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) {
          setState(() {
            _focused = value;
          });
        },
        onKeyEvent: _onKey,
        child: AnimatedScale(
          scale: focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              canRequestFocus: false,
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 10 : 12,
                  vertical: vPad,
                ),
                decoration: BoxDecoration(
                  gradient: lit
                      ? LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: focused
                              ? [
                                  kColorPrimary.withValues(alpha: 0.98),
                                  kColorPrimaryDark.withValues(alpha: 0.90),
                                ]
                              : [
                                  kColorPrimary.withValues(alpha: 0.38),
                                  kColorPrimary.withValues(alpha: 0.10),
                                ],
                        )
                      : null,
                  color: lit ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    width: focused ? 2.4 : (selected ? 1.6 : 1.0),
                    color: focused
                        ? kColorFocus
                        : selected
                            ? kColorPrimary.withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.04),
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: kColorPrimary.withValues(alpha: 0.62),
                            blurRadius: 22,
                          ),
                        ]
                      : selected
                          ? [
                              BoxShadow(
                                color: kColorPrimary.withValues(alpha: 0.48),
                                blurRadius: 20,
                                spreadRadius: 0.4,
                              ),
                            ]
                          : null,
                ),
                child: widget.collapsed
                    ? Center(
                        child: Icon(
                          widget.item.icon,
                          color: lit
                              ? (focused ? Colors.black : Colors.white)
                              : Colors.white54,
                          size: iconSize,
                        ),
                      )
                    : Row(
                        children: [
                          if (selected && !focused)
                            Container(
                              width: 4,
                              height: 22,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: kColorPrimary,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: kColorPrimary.withValues(alpha: 0.8),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          Icon(
                            widget.item.icon,
                            color: lit
                                ? (focused ? Colors.black : Colors.white)
                                : Colors.white54,
                            size: iconSize,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: lit
                                    ? (focused ? Colors.black : Colors.white)
                                    : Colors.white60,
                                fontSize: fontSize,
                                fontWeight: lit
                                    ? FontWeight.w800
                                    : FontWeight.w600,
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
