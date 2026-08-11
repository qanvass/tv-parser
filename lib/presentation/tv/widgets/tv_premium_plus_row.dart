import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../repository/models/premium_plus_item.dart';
import '../../widgets/smart_channel_logo.dart';
import 'tv_channel_grid.dart';

class TvPremiumPlusRow extends StatelessWidget {
  final List<PremiumPlusItem> items;
  final ValueChanged<dynamic> onPlayChannel;
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const TvPremiumPlusRow({
    super.key,
    required this.items,
    required this.onPlayChannel,
    this.onStreamFocused,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TvRailSectionHeader(
          title: 'Featured Channels',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: TvChannelCard.tileHeight + 20,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final ch = item.matchedChannel;
              final stream = TvStreamRecord(
                title: item.displayName,
                subtitle: item.category,
                streamUrl: ch?.directSource?.isNotEmpty == true
                    ? ch!.directSource!
                    : (ch?.streamId ?? ''),
                imageUrl: ch?.streamIcon,
                isHd: item.displayName.toUpperCase().contains('HD'),
              );
              return Padding(
                padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
                child: TvChannelCard(
                  stream: stream,
                  onSelected: () {
                    if (ch != null) onPlayChannel(ch);
                  },
                  onFocused: onStreamFocused,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Wider featured tile used when a richer card is preferred over the dense tile.
class TvPremiumPlusCard extends StatefulWidget {
  final PremiumPlusItem item;
  final VoidCallback onTap;

  const TvPremiumPlusCard({super.key, required this.item, required this.onTap});

  @override
  State<TvPremiumPlusCard> createState() => _TvPremiumPlusCardState();
}

class _TvPremiumPlusCardState extends State<TvPremiumPlusCard> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (widget.item.matchedChannel == null) return KeyEventResult.ignored;
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
    final iconUrl = widget.item.matchedChannel?.streamIcon?.trim() ?? '';

    return AnimatedScale(
      scale: _focused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 280,
        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A3040), Color(0xFF0C1622)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused
                ? const Color(0xFFF2F2F5)
                : Colors.white.withValues(alpha: 0.08),
            width: _focused ? 1.3 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          onKeyEvent: _onKey,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              canRequestFocus: false,
              onTap: widget.item.matchedChannel == null ? null : widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: SmartChannelLogo(
                        primaryUrl: iconUrl.isEmpty ? null : iconUrl,
                        channelName: widget.item.displayName,
                        fit: BoxFit.contain,
                        memCacheWidth: 180,
                        initialsSize: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
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
        ),
      ),
    );
  }
}
