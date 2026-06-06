import 'channel_live.dart';

class PremiumPlusItem {
  final String id;
  final String displayName;
  final List<String> aliases;
  final String category;
  final int priority;
  final String? badgeLabel;
  final ChannelLive? matchedChannel;
  final double confidenceScore;

  const PremiumPlusItem({
    required this.id,
    required this.displayName,
    required this.aliases,
    required this.category,
    required this.priority,
    this.badgeLabel,
    this.matchedChannel,
    this.confidenceScore = 0.0,
  });

  PremiumPlusItem copyWith({
    ChannelLive? matchedChannel,
    double? confidenceScore,
  }) {
    return PremiumPlusItem(
      id: id,
      displayName: displayName,
      aliases: aliases,
      category: category,
      priority: priority,
      badgeLabel: badgeLabel,
      matchedChannel: matchedChannel ?? this.matchedChannel,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}
