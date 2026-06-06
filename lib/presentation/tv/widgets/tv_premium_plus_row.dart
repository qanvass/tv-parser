import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../repository/models/premium_plus_item.dart';

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
    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Plus Header Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.stars_rounded,
                color: Colors.amber.shade400,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                "Premium Plus",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Brand Cards Carousel
        SizedBox(
          height: 160, // Height matching card constraints + scale room
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 18.0, top: 8.0, bottom: 8.0),
                child: TvPremiumPlusCard(
                  item: item,
                  onTap: () {
                    if (item.matchedChannel != null) {
                      onPlayChannel(item.matchedChannel!);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BrandStyle {
  final List<Color> gradientColors;
  final Color accentColor;
  final TextStyle textStyle;
  final String textLabel;

  const BrandStyle({
    required this.gradientColors,
    required this.accentColor,
    required this.textStyle,
    required this.textLabel,
  });
}

class TvPremiumPlusCard extends StatefulWidget {
  final PremiumPlusItem item;
  final VoidCallback onTap;

  const TvPremiumPlusCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<TvPremiumPlusCard> createState() => _TvPremiumPlusCardState();
}

class _TvPremiumPlusCardState extends State<TvPremiumPlusCard> {
  bool _focused = false;

  BrandStyle _getBrandStyle(String id, String defaultName) {
    switch (id.toLowerCase()) {
      case 'cnn':
        return BrandStyle(
          gradientColors: [const Color(0xFF4A0E17), const Color(0xFF150406)],
          accentColor: const Color(0xFFCC181E),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            shadows: [
              Shadow(
                color: Color(0xFFCC181E),
                blurRadius: 10,
              ),
            ],
          ),
          textLabel: "CNN",
        );
      case 'bbc':
        return BrandStyle(
          gradientColors: [const Color(0xFF2E2E2E), const Color(0xFF0F0F0F)],
          accentColor: Colors.white,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 6.0,
          ),
          textLabel: "BBC",
        );
      case 'hbo':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF0A0A0A)],
          accentColor: Colors.white70,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                color: Colors.white24,
                blurRadius: 8,
              ),
            ],
          ),
          textLabel: "HBO",
        );
      case 'starz':
        return BrandStyle(
          gradientColors: [const Color(0xFF26103C), const Color(0xFF0E0518)],
          accentColor: const Color(0xFF8A2BE2),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 6.0,
          ),
          textLabel: "STARZ",
        );
      case 'max':
        return BrandStyle(
          gradientColors: [const Color(0xFF003087), const Color(0xFF000F30)],
          accentColor: const Color(0xFF0056FF),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            shadows: [
              Shadow(
                color: Color(0xFF0056FF),
                blurRadius: 12,
              ),
            ],
          ),
          textLabel: "max",
        );
      case 'disney':
        return BrandStyle(
          gradientColors: [const Color(0xFF002244), const Color(0xFF000D1A)],
          accentColor: const Color(0xFF00A3E0),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 4.0,
            shadows: [
              Shadow(
                color: Color(0xFF00A3E0),
                blurRadius: 8,
              ),
            ],
          ),
          textLabel: "Disney",
        );
      case 'showtime':
        return BrandStyle(
          gradientColors: [const Color(0xFF3B0C11), const Color(0xFF140305)],
          accentColor: const Color(0xFFE50914),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Color(0xFFE50914),
                blurRadius: 8,
              ),
            ],
          ),
          textLabel: "SHOWTIME",
        );
      case 'cinemax':
        return BrandStyle(
          gradientColors: [const Color(0xFF0B2530), const Color(0xFF030D12)],
          accentColor: const Color(0xFF00A4E4),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.0,
          ),
          textLabel: "CINEMAX",
        );
      case 'nickelodeon':
        return BrandStyle(
          gradientColors: [const Color(0xFF4A1E0B), const Color(0xFF1B0A03)],
          accentColor: const Color(0xFFFF5F1F),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Color(0xFFFF5F1F),
                blurRadius: 8,
              ),
            ],
          ),
          textLabel: "nick",
        );
      case 'cartoon_network':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF0F0F0F)],
          accentColor: Colors.white70,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(2, 2)),
            ],
          ),
          textLabel: "CN",
        );
      case 'hallmark':
        return BrandStyle(
          gradientColors: [const Color(0xFF3A241C), const Color(0xFF140D0A)],
          accentColor: const Color(0xFFFFD700),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'serif',
          ),
          textLabel: "Hallmark",
        );
      case 'fx':
        return BrandStyle(
          gradientColors: [const Color(0xFF2C2415), const Color(0xFF120E08)],
          accentColor: const Color(0xFFFFC72C),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                color: Color(0xFFFFC72C),
                blurRadius: 8,
              ),
            ],
          ),
          textLabel: "FX",
        );
      case 'amc':
        return BrandStyle(
          gradientColors: [const Color(0xFF351C1E), const Color(0xFF150A0B)],
          accentColor: const Color(0xFFC8102E),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          textLabel: "AMC",
        );
      case 'discovery':
        return BrandStyle(
          gradientColors: [const Color(0xFF0F2E3A), const Color(0xFF051015)],
          accentColor: const Color(0xFF00A4E4),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          ),
          textLabel: "DISCOVERY",
        );
      case 'hgtv':
        return BrandStyle(
          gradientColors: [const Color(0xFF0A2E26), const Color(0xFF03100C)],
          accentColor: const Color(0xFF00FFCC),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          textLabel: "HGTV",
        );
      case 'food_network':
        return BrandStyle(
          gradientColors: [const Color(0xFF381512), const Color(0xFF140706)],
          accentColor: const Color(0xFFFF4500),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          textLabel: "food network",
        );
      case 'paramount':
        return BrandStyle(
          gradientColors: [const Color(0xFF0D253A), const Color(0xFF040B12)],
          accentColor: const Color(0xFF00BFFF),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
          textLabel: "PARAMOUNT",
        );
      case 'bet':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF080808)],
          accentColor: Colors.white,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
          textLabel: "BET",
        );
      case 'bet_plus':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF080808)],
          accentColor: Colors.blueAccent,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
          textLabel: "BET+",
        );
      case 'ppv':
        return BrandStyle(
          gradientColors: [const Color(0xFF3E1C00), const Color(0xFF160A00)],
          accentColor: const Color(0xFFFF8C00),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            shadows: [
              Shadow(
                color: Color(0xFFFF8C00),
                blurRadius: 10,
              ),
            ],
          ),
          textLabel: "PPV EVENTS",
        );
      case 'espn':
        return BrandStyle(
          gradientColors: [const Color(0xFF3C0F12), const Color(0xFF140405)],
          accentColor: const Color(0xFFCC181E),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            shadows: [
              Shadow(color: Color(0xFFCC181E), offset: Offset(2, 2)),
            ],
          ),
          textLabel: "ESPN",
        );
      case 'msnbc':
        return BrandStyle(
          gradientColors: [const Color(0xFF0C1938), const Color(0xFF030814)],
          accentColor: const Color(0xFF1F4E9F),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textLabel: "msnbc",
        );
      case 'fox_news':
        return BrandStyle(
          gradientColors: [const Color(0xFF0F1E38), const Color(0xFF040810)],
          accentColor: const Color(0xFF003366),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          textLabel: "FOX NEWS",
        );
      default:
        return BrandStyle(
          gradientColors: [const Color(0xFF231C35), const Color(0xFF13101E)],
          accentColor: const Color(0xFFFFC107),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textLabel: defaultName,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandStyle = _getBrandStyle(widget.item.id, widget.item.displayName);
    final streamIcon = widget.item.matchedChannel?.streamIcon;
    final hasStreamIcon = streamIcon != null && streamIcon.startsWith('http');

    return Focus(
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
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _focused ? Colors.white : brandStyle.accentColor.withValues(alpha: 0.15),
                  width: _focused ? 2.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _focused 
                        ? brandStyle.accentColor.withValues(alpha: 0.35) 
                        : brandStyle.accentColor.withValues(alpha: 0.08),
                    blurRadius: _focused ? 24 : 10,
                    spreadRadius: _focused ? 2 : 0,
                    offset: _focused ? const Offset(0, 4) : const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Background layer (Stream icon or gradient fallback)
                  Positioned.fill(
                    child: hasStreamIcon
                        ? CachedNetworkImage(
                            imageUrl: streamIcon,
                            fit: BoxFit.cover,
                            memCacheWidth: 600, // TV brand card resolution limit
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: brandStyle.gradientColors,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: brandStyle.gradientColors,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: brandStyle.gradientColors,
                              ),
                            ),
                          ),
                  ),

                  // Contrast overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.40),
                            Colors.black.withValues(alpha: 0.80),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top badge
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(widget.item.category).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getCategoryColor(widget.item.category).withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            widget.item.badgeLabel ?? widget.item.category,
                            style: TextStyle(
                              color: _getCategoryColor(widget.item.category),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.amber.shade400.withValues(alpha: 0.8),
                          size: 16,
                        ),
                      ],
                    ),
                  ),

                  // Centered Text Brand Fallback (strictly no Wikimedia logo files)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 15, bottom: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          brandStyle.textLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: brandStyle.textStyle,
                        ),
                      ),
                    ),
                  ),

                  // Bottom matched channel title
                  Positioned(
                    left: 18,
                    bottom: 14,
                    right: 60,
                    child: Text(
                      widget.item.matchedChannel?.name ?? "Unavailable",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),

                  // Play Button overlay
                  Positioned(
                    right: 18,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: brandStyle.accentColor,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: ThemeData.estimateBrightnessForColor(brandStyle.accentColor) == Brightness.light
                            ? Colors.black
                            : Colors.white,
                        size: 16,
                      ),
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

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'NEWS':
        return Colors.blue.shade300;
      case 'PREMIUM':
        return Colors.purple.shade300;
      case 'SPORTS':
        return Colors.green.shade300;
      case 'PPV':
        return Colors.orange.shade300;
      default:
        return Colors.teal.shade300;
    }
  }
}
