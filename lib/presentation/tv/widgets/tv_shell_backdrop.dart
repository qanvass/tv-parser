import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';
import '../../../repository/api/artwork_url_resolver.dart';

/// Full-bleed focused-item backdrop with a left-to-right readability scrim.
class TvShellBackdrop extends StatelessWidget {
  final String? imageUrl;

  const TvShellBackdrop({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = ArtworkUrlResolver.isUsableImageUrl(imageUrl) ? imageUrl : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050A18)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: url == null
              ? const SizedBox.expand(key: ValueKey('nobackdrop'))
              : CachedNetworkImage(
                  key: ValueKey(url),
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: 1280,
                  fadeInDuration: const Duration(milliseconds: 280),
                  placeholder: (_, __) => const ColoredBox(color: kColorBackDark),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: kColorBackDark),
                ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xF2050A12),
                Color(0xD6050A12),
                Color(0x99050A12),
                Color(0xCC050A12),
              ],
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66050A12),
                Color(0x00050A12),
                Color(0xE6050A12),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
