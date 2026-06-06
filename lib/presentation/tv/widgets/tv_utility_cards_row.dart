import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import '../../../../repository/models/channel_live.dart';
import '../../mobile/all_content_screen.dart';
import '../../mobile/local_tv_screen.dart';

class TvUtilityCardsRow extends StatelessWidget {
  final List<ChannelLive> allLiveChannels;
  final ValueChanged<String> onChannelSelected;
  final bool showLocal;

  const TvUtilityCardsRow({
    super.key,
    required this.allLiveChannels,
    required this.onChannelSelected,
    required this.showLocal,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      if (showLocal)
        {"title": "Local TV", "icon": Icons.location_on_rounded, "isLocal": true, "color": Colors.amber},
      {"title": "All Channels • 20,000+", "icon": Icons.live_tv_rounded, "isLocal": false, "mode": BrowseMode.live, "color": const Color(0xFFFFC107)},
      {"title": "All Movies", "icon": Icons.movie_outlined, "isLocal": false, "mode": BrowseMode.movies, "color": const Color(0xFFFF416C)},
      {"title": "All Series", "icon": Icons.video_library_outlined, "isLocal": false, "mode": BrowseMode.series, "color": const Color(0xFF00C6FF)},
      {"title": "Browse Countries", "icon": Icons.flag_outlined, "isLocal": false, "mode": BrowseMode.countries, "color": Colors.tealAccent},
      {"title": "Browse Languages", "icon": Icons.language_outlined, "isLocal": false, "mode": BrowseMode.languages, "color": Colors.purpleAccent},
      {"title": "Categories", "icon": Icons.dashboard_customize_outlined, "isLocal": false, "mode": BrowseMode.categories, "color": Colors.pinkAccent},
    ];

    return SizedBox(
      height: 120, // Height allowed for scale & shadow
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          final title = item["title"] as String;

          return Padding(
            padding: const EdgeInsets.only(right: 18.0, top: 8.0, bottom: 8.0),
            child: TvUtilityCard(
              title: title,
              icon: item["icon"] as IconData,
              onTap: () {
                if (item["isLocal"] == true) {
                  Get.to(() => LocalTvScreen(
                        allLiveChannels: allLiveChannels,
                        onPlayChannel: (ch) {
                          if (ch.directSource != null && ch.directSource!.isNotEmpty) {
                            onChannelSelected(ch.directSource!);
                          } else if (ch.streamId != null) {
                            onChannelSelected(ch.streamId!);
                          }
                        },
                      ));
                } else {
                  Get.to(() => AllContentScreen(initialMode: item["mode"] as BrowseMode));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class TvUtilityCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const TvUtilityCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  State<TvUtilityCard> createState() => _TvUtilityCardState();
}

class _TvUtilityCardState extends State<TvUtilityCard> {
  bool _focused = false;

  List<Color> getCardGradient(String title) {
    final cleanTitle = title.toLowerCase();
    if (cleanTitle.contains('channels')) {
      return [const Color(0xFFCC181E), const Color(0xFF7A0F12)]; // Red
    } else if (cleanTitle.contains('movies')) {
      return [const Color(0xFFE65100), const Color(0xFFB33600)]; // Orange
    } else if (cleanTitle.contains('series')) {
      return [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]; // Green
    } else if (cleanTitle.contains('countries')) {
      return [const Color(0xFF1976D2), const Color(0xFF0D47A1)]; // Blue
    } else if (cleanTitle.contains('languages')) {
      return [const Color(0xFF7B1FA2), const Color(0xFF4A148C)]; // Purple
    } else if (cleanTitle.contains('categories')) {
      return [const Color(0xFF00796B), const Color(0xFF004D40)]; // Teal
    } else if (cleanTitle.contains('local')) {
      return [const Color(0xFFFFB300), const Color(0xFFB58900)]; // Gold/Amber
    }
    return [const Color(0xFF231C35), const Color(0xFF13101E)];
  }

  Color getCardAccent(String title) {
    final cleanTitle = title.toLowerCase();
    if (cleanTitle.contains('channels')) {
      return const Color(0xFFCC181E);
    } else if (cleanTitle.contains('movies')) {
      return const Color(0xFFFF5722);
    } else if (cleanTitle.contains('series')) {
      return const Color(0xFF2E7D32);
    } else if (cleanTitle.contains('countries')) {
      return const Color(0xFF1976D2);
    } else if (cleanTitle.contains('languages')) {
      return const Color(0xFF7B1FA2);
    } else if (cleanTitle.contains('categories')) {
      return const Color(0xFF00796B);
    } else if (cleanTitle.contains('local')) {
      return const Color(0xFFFFC107);
    }
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final accent = getCardAccent(widget.title);

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
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 160,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: getCardGradient(widget.title),
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _focused ? Colors.white : accent.withValues(alpha: 0.25),
                  width: _focused ? 2.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _focused 
                        ? accent.withValues(alpha: 0.35) 
                        : accent.withValues(alpha: 0.18),
                    blurRadius: _focused ? 16 : 8,
                    spreadRadius: _focused ? 1 : 0,
                    offset: _focused ? const Offset(0, 4) : const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 1),
                          blurRadius: 2,
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
    );
  }
}
