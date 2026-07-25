import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../repository/models/premium_plus_item.dart';

class TvPremiumPlusRow extends StatelessWidget {
  final List<PremiumPlusItem> items;
  final ValueChanged<dynamic> onPlayChannel;

  const TvPremiumPlusRow({
    super.key,
    required this.items,
    required this.onPlayChannel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Channels',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 154,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return TvPremiumPlusCard(
                item: item,
                onTap: () {
                  final channel = item.matchedChannel;
                  if (channel != null) onPlayChannel(channel);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class TvPremiumPlusCard extends StatefulWidget {
  final PremiumPlusItem item;
  final VoidCallback onTap;

  const TvPremiumPlusCard({super.key, required this.item, required this.onTap});

  @override
  State<TvPremiumPlusCard> createState() => _TvPremiumPlusCardState();
}

class _TvPremiumPlusCardState extends State<TvPremiumPlusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final iconUrl = widget.item.matchedChannel?.streamIcon?.trim() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 310,
      margin: const EdgeInsets.only(right: 18, bottom: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2242), Color(0xFF17121F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused ? Colors.white : Colors.white.withValues(alpha: 0.08),
          width: _focused ? 3 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onFocusChange: (focused) => setState(() => _focused = focused),
          onTap: widget.item.matchedChannel == null ? null : widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: iconUrl.isEmpty
                      ? const Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white70,
                          size: 38,
                        )
                      : CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.live_tv_rounded,
                            color: Colors.white70,
                            size: 38,
                          ),
                        ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
