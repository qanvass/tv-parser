import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../repository/models/premium_plus_item.dart';

const bool enableRemoteBrandLogoOverrides = false;

class BrandStyle {
  final List<Color> gradientColors;
  final Color accentColor;
  final String? remoteLogoUrl;
  final TextStyle textStyle;
  final String textLabel;

  const BrandStyle({
    required this.gradientColors,
    required this.accentColor,
    this.remoteLogoUrl,
    required this.textStyle,
    required this.textLabel,
  });
}

class PremiumPlusCard extends StatelessWidget {
  final PremiumPlusItem item;
  final VoidCallback onTap;

  const PremiumPlusCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  BrandStyle _getBrandStyle(String id, String defaultName) {
    switch (id.toLowerCase()) {
      case 'cnn':
        return BrandStyle(
          gradientColors: [const Color(0xFF4A0E17), const Color(0xFF150406)],
          accentColor: const Color(0xFFCC181E),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/CNN.svg/512px-CNN.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/BBC_Logo_2021.svg/512px-BBC_Logo_2021.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 6.0,
          ),
          textLabel: "BBC",
        );
      case 'hbo':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF0A0A0A)],
          accentColor: Colors.white70,
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/HBO_logo.svg/512px-HBO_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 28,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Starz_logo_2016.svg/512px-Starz_logo_2016.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 6.0,
          ),
          textLabel: "STARZ",
        );
      case 'max':
        return BrandStyle(
          gradientColors: [const Color(0xFF003087), const Color(0xFF000F30)],
          accentColor: const Color(0xFF0056FF),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ce/Max_logo.svg/512px-Max_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 30,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Disney_wordmark.svg/512px-Disney_wordmark.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/Showtime_landing_logo.svg/512px-Showtime_landing_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Cinemax_logo_2011.svg/512px-Cinemax_logo_2011.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Nickelodeon_2023.svg/512px-Nickelodeon_2023.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Cartoon_Network_2010_logo.svg/512px-Cartoon_Network_2010_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Hallmark_Channel_logo.svg/512px-Hallmark_Channel_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'serif',
          ),
          textLabel: "Hallmark",
        );
      case 'fx':
        return BrandStyle(
          gradientColors: [const Color(0xFF2C2415), const Color(0xFF120E08)],
          accentColor: const Color(0xFFFFC72C),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/FX_Network_logo.svg/512px-FX_Network_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/AMC_logo.svg/512px-AMC_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          textLabel: "AMC",
        );
      case 'discovery':
        return BrandStyle(
          gradientColors: [const Color(0xFF0F2E3A), const Color(0xFF051015)],
          accentColor: const Color(0xFF00A4E4),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Discovery_Channel_logo_2019.svg/512px-Discovery_Channel_logo_2019.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          ),
          textLabel: "DISCOVERY",
        );
      case 'hgtv':
        return BrandStyle(
          gradientColors: [const Color(0xFF0A2E26), const Color(0xFF03100C)],
          accentColor: const Color(0xFF00FFCC),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/HGTV_Logo_2015.svg/512px-HGTV_Logo_2015.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          textLabel: "HGTV",
        );
      case 'food_network':
        return BrandStyle(
          gradientColors: [const Color(0xFF381512), const Color(0xFF140706)],
          accentColor: const Color(0xFFFF4500),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Food_Network_logo.svg/512px-Food_Network_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          textLabel: "food network",
        );
      case 'paramount':
        return BrandStyle(
          gradientColors: [const Color(0xFF0D253A), const Color(0xFF040B12)],
          accentColor: const Color(0xFF00BFFF),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Paramount_Network_logo_2018.svg/512px-Paramount_Network_logo_2018.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
          textLabel: "PARAMOUNT",
        );
      case 'bet':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF080808)],
          accentColor: Colors.white,
          remoteLogoUrl: '',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
          textLabel: "BET",
        );
      case 'bet_plus':
        return BrandStyle(
          gradientColors: [const Color(0xFF222222), const Color(0xFF080808)],
          accentColor: Colors.blueAccent,
          remoteLogoUrl: '',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
          textLabel: "BET+",
        );
      case 'ppv':
        return BrandStyle(
          gradientColors: [const Color(0xFF3E1C00), const Color(0xFF160A00)],
          accentColor: const Color(0xFFFF8C00),
          remoteLogoUrl: '',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/ESPN_wordmark.svg/512px-ESPN_wordmark.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 26,
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
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Msnbc_logo.svg/512px-Msnbc_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textLabel: "msnbc",
        );
      case 'fox_news':
        return BrandStyle(
          gradientColors: [const Color(0xFF0F1E38), const Color(0xFF040810)],
          accentColor: const Color(0xFF003366),
          remoteLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Fox_News_Channel_logo.svg/512px-Fox_News_Channel_logo.svg.png',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textLabel: defaultName,
        );
    }
  }

  Widget _buildBrandLogoOrText(BrandStyle brandStyle) {
    if (enableRemoteBrandLogoOverrides &&
        brandStyle.remoteLogoUrl != null &&
        brandStyle.remoteLogoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: brandStyle.remoteLogoUrl!,
        height: 32,
        fit: BoxFit.contain,
        memCacheHeight: 64,
        placeholder: (context, url) => _buildStyledTextFallback(brandStyle),
        errorWidget: (context, url, error) => _buildStyledTextFallback(brandStyle),
      );
    } else {
      return _buildStyledTextFallback(brandStyle);
    }
  }

  Widget _buildStyledTextFallback(BrandStyle brandStyle) {
    return Text(
      brandStyle.textLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: brandStyle.textStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandStyle = _getBrandStyle(item.id, item.displayName);
    final streamIcon = item.matchedChannel?.streamIcon;
    final hasStreamIcon = streamIcon != null && streamIcon.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: brandStyle.accentColor.withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: brandStyle.accentColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Layer (Stream icon or custom gradient fallback)
            Positioned.fill(
              child: hasStreamIcon
                  ? CachedNetworkImage(
                      imageUrl: streamIcon,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
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

            // Soft transparency overlay gradient for high readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.08),
                      Colors.black.withOpacity(0.40),
                      Colors.black.withOpacity(0.80),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Decorative background glowing aura
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: brandStyle.accentColor.withOpacity(0.18),
                      blurRadius: 24,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
            ),

            // Top badge and verified icon
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
                      color: _getCategoryColor(item.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getCategoryColor(item.category).withOpacity(0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      item.badgeLabel ?? item.category,
                      style: TextStyle(
                        color: _getCategoryColor(item.category),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.amber.shade400.withOpacity(0.8),
                    size: 16,
                  ),
                ],
              ),
            ),

            // Front and center brand logo or stylized text lockup
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 15, bottom: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: brandStyle.accentColor.withOpacity(0.1),
                        blurRadius: 16,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: _buildBrandLogoOrText(brandStyle),
                ),
              ),
            ),

            // Matched playlist channel label (bottom left)
            Positioned(
              left: 18,
              bottom: 14,
              right: 60, // leaves room for play button on the right
              child: Text(
                item.matchedChannel?.name ?? "Unavailable",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
                  ],
                ),
              ),
            ),

            // Play Icon overlay decoration (bottom right)
            Positioned(
              right: 18,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandStyle.accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: brandStyle.accentColor.withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
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
