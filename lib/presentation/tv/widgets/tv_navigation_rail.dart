import 'package:flutter/material.dart';

class TvNavigationItem {
  final String label;
  final IconData icon;

  const TvNavigationItem({
    required this.label,
    required this.icon,
  });
}

class TvNavigationRail extends StatelessWidget {
  final List<TvNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FocusNode>? focusNodes;

  const TvNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.focusNodes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 18),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 4, 22, 22),
            child: Text(
              'TV Parser',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _TvNavigationButton(
                  item: items[index],
                  selected: selectedIndex == index,
                  focusNode: focusNodes != null && index < focusNodes!.length
                      ? focusNodes![index]
                      : null,
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
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

  const _TvNavigationButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<_TvNavigationButton> createState() => _TvNavigationButtonState();
}

class _TvNavigationButtonState extends State<_TvNavigationButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.selected || _focused;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        focusNode: widget.focusNode,
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
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    width: active ? 2.5 : 1.0,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      color: active ? Colors.white : Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white60,
                          fontSize: 16,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
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
