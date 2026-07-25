import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PremiumChannelCard extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final bool isLive;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isTv;
  final FocusNode? focusNode;
  final bool? isFocused;

  const PremiumChannelCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.isLive = true,
    this.isFavorite = false,
    required this.onTap,
    this.onLongPress,
    this.isTv = false,
    this.focusNode,
    this.isFocused,
  });

  @override
  State<PremiumChannelCard> createState() => _PremiumChannelCardState();
}

class _PremiumChannelCardState extends State<PremiumChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final focused = widget.isFocused ?? _isFocused;
    // Always focusable (not just when isTv is explicitly passed) so a
    // D-pad/remote or bluetooth keyboard can always reach and activate
    // this card, regardless of what the caller passed in.
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (value) {
        setState(() {
          _isFocused = value;
        });
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: focused ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: _buildCardBody(focused),
        ),
      ),
    );
  }

  Widget _buildCardBody(bool focused) {
    final hasLogo =
        widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty;
    final cardBorderColor = focused
        ? const Color(0xFFFFC107) // Gold focus border
        : Colors.white.withOpacity(0.06);

    final List<BoxShadow> cardGlow = focused
        ? [
            BoxShadow(
              color: const Color(0xFFFFC107).withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ]
        : [];

    final String? resBadge = _detectResolution(widget.title);

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131315),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: focused ? 2.5 : 1.2),
        boxShadow: cardGlow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Logo Area with padded alignment and BoxFit.contain
          Positioned.fill(
            bottom: widget.isTv ? 56 : 46, // Space for title gradient
            child: Container(
              color: const Color(0xFF0C0C0D),
              padding: const EdgeInsets.all(14),
              child: Center(
                child: hasLogo
                    ? CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        fit: BoxFit.contain,
                        memCacheWidth: 200,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (context, url) => Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.5),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildFallbackLogo(),
                      )
                    : _buildFallbackLogo(),
              ),
            ),
          ),

          // Bottom gradient and title overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: widget.isTv ? 58 : 48,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00131315),
                    Color(0xCC131315),
                    Color(0xFF131315),
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.bottomLeft,
              child: Text(
                widget.title,
                maxLines: widget.isTv ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: focused ? const Color(0xFFFFC107) : Colors.white,
                  fontSize: widget.isTv ? 13 : 11,
                  fontWeight: widget.isTv ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ),

          // LIVE Badge top-left
          if (widget.isLive)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // HD/FHD Badge top-right
          if (resBadge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  resBadge,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

          // TV Focus play icon indicator
          if (focused)
            Positioned(
              top: 10,
              right: resBadge != null ? 36 : 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC107),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );

    return widget.isTv
        ? SizedBox(width: 170, height: 146, child: cardContent)
        : cardContent;
  }

  Widget _buildFallbackLogo() {
    return Icon(
      Icons.live_tv_rounded,
      color: Colors.white.withOpacity(0.08),
      size: widget.isTv ? 38 : 30,
    );
  }

  String? _detectResolution(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("4k") || lower.contains("uhd")) return "4K";
    if (lower.contains("fhd") || lower.contains("1080")) return "FHD";
    if (lower.contains("hd") || lower.contains("720")) return "HD";
    return null;
  }
}
