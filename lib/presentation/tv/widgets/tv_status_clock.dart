import 'dart:async';

import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';

/// Real device time/date in the mockup status slot. Never a hardcoded clock.
class TvStatusClock extends StatefulWidget {
  const TvStatusClock({super.key});

  @override
  State<TvStatusClock> createState() => _TvStatusClockState();
}

class _TvStatusClockState extends State<TvStatusClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final mer = _now.hour >= 12 ? 'PM' : 'AM';
    final min = _now.minute.toString().padLeft(2, '0');
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final date =
        '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$hour:$min $mer',
              style: const TextStyle(
                color: Color(0xFF00D2FF),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              date,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.wifi_rounded,
          color: Colors.white.withValues(alpha: 0.55),
          size: 18,
        ),
      ],
    );
  }
}

class TvStatsStrip extends StatelessWidget {
  final int liveGroups;
  final int movies;
  final int series;
  final int playlistEntries;

  const TvStatsStrip({
    super.key,
    required this.liveGroups,
    required this.movies,
    required this.series,
    required this.playlistEntries,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      if (liveGroups > 0) (Icons.live_tv_rounded, '$liveGroups', 'Live groups'),
      if (movies > 0) (Icons.local_movies_rounded, _fmt(movies), 'Movies'),
      if (series > 0) (Icons.tv_rounded, _fmt(series), 'Series'),
      if (playlistEntries > 0)
        (Icons.playlist_play_rounded, _fmt(playlistEntries), 'Playlist entries'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            width: 176,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x99050A18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kColorPrimary.withValues(alpha: 0.38)),
              boxShadow: [
                BoxShadow(
                  color: kColorPrimary.withValues(alpha: 0.16),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(item.$1, color: kColorPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmt(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
