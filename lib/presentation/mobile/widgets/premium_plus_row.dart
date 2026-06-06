import 'package:flutter/material.dart';
import '../../../../repository/models/premium_plus_item.dart';
import 'premium_plus_card.dart';

class PremiumPlusRow extends StatelessWidget {
  final List<PremiumPlusItem> items;
  final ValueChanged<dynamic> onPlayChannel;

  const PremiumPlusRow({
    super.key,
    required this.items,
    required this.onPlayChannel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
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
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Premium Plus",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade500.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "DEBUG",
                    style: TextStyle(
                      color: Colors.amber.shade400,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 128,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF231C35), Color(0xFF13101E)],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Premium Plus",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "No matches yet — check aliases or playlist labels",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

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
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                "Premium Plus",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade500.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "CURATED",
                  style: TextStyle(
                    color: Colors.amber.shade400,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Brand Cards Carousel
        SizedBox(
          height: 128, // Height matching card constraints
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            cacheExtent: 300.0,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return PremiumPlusCard(
                item: item,
                onTap: () {
                  if (item.matchedChannel != null) {
                    onPlayChannel(item.matchedChannel!);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
