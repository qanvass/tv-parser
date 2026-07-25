import 'package:flutter/material.dart';

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
    final width = collapsed ? 88.0 : 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 12 : 22,
              2,
              collapsed ? 12 : 22,
              12,
            ),
            child: collapsed
                ? const Icon(Icons.tv_rounded, color: Colors.white, size: 26)
                : const Text(
                    'TV Parser',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
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

  @override
  Widget build(BuildContext context) {
    final bool active = widget.selected || _focused;
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
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 12 : 14,
                  vertical: vPad,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    width: active ? 2.5 : 1.0,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: widget.collapsed
                    ? Center(
                        child: Icon(
                          widget.item.icon,
                          color: active ? Colors.white : Colors.white54,
                          size: iconSize,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            widget.item.icon,
                            color: active ? Colors.white : Colors.white54,
                            size: iconSize,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? Colors.white : Colors.white60,
                                fontSize: fontSize,
                                fontWeight: active
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
