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

  static const Color _surface = Color(0xE6090B0F);
  static const Duration _motion = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 92.0 : 236.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 22,
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
                      collapsed ? 12 : 20,
                      2,
                      collapsed ? 12 : 20,
                      collapsed ? 12 : 10,
                    ),
                    child: collapsed
                        ? const Center(
                            child: SizedBox(
                              width: 56,
                              height: 44,
                              child: Image(
                                image: AssetImage(kIconLogoTransparent),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                gaplessPlayback: true,
                              ),
                            ),
                          )
                        : const Column(
                            children: [
                              SizedBox(
                                width: 168,
                                height: 118,
                                child: Image(
                                  image: AssetImage(kIconLogoTransparent),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Media Player',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xB300A3FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                  height: 1.1,
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
                                    focusNodes != null &&
                                        index < focusNodes!.length
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
                        color: Colors.white.withValues(alpha: 0.08),
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
    final vPad = widget.compact ? 8.0 : 15.0;
    final iconSize = widget.compact ? 22.0 : 24.0;
    final fontSize = widget.compact ? 15.0 : 16.0;

    final Color iconColor;
    final Color labelColor;
    if (focused) {
      iconColor = const Color(0xFFF7F7F8);
      labelColor = const Color(0xFFF7F7F8);
    } else if (selected) {
      iconColor = const Color(0xFFE8F4FF);
      labelColor = const Color(0xFFF2F2F5);
    } else {
      iconColor = const Color(0x99FFFFFF);
      labelColor = const Color(0x8AFFFFFF);
    }

    final Color? tileColor;
    if (focused) {
      tileColor = const Color(0xCC161A22);
    } else if (selected) {
      tileColor = const Color(0x9912161C);
    } else {
      tileColor = Colors.transparent;
    }

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
          scale: focused ? 1.03 : 1.0,
          duration: TvNavigationRail._motion,
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              canRequestFocus: false,
              onTap: widget.onTap,
              splashColor: Colors.white.withValues(alpha: 0.04),
              highlightColor: Colors.white.withValues(alpha: 0.03),
              child: AnimatedContainer(
                duration: TvNavigationRail._motion,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 10 : 12,
                  vertical: vPad,
                ),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(14),
                  border: focused
                      ? Border.all(
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.16),
                        )
                      : null,
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (selected)
                      Positioned(
                        left: 0,
                        top: widget.collapsed ? 2 : 4,
                        bottom: widget.collapsed ? 2 : 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: kColorPrimary.withValues(
                              alpha: focused ? 0.80 : 0.55,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const SizedBox(width: 2),
                        ),
                      ),
                    widget.collapsed
                        ? Center(
                            child: Icon(
                              widget.item.icon,
                              color: iconColor,
                              size: iconSize,
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.only(left: selected ? 10 : 0),
                            child: Row(
                              children: [
                                Icon(
                                  widget.item.icon,
                                  color: iconColor,
                                  size: iconSize,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: labelColor,
                                      fontSize: fontSize,
                                      fontWeight: (focused || selected)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
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
