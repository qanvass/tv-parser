/// Compact XMLTV records kept after parse. Never invent titles or art.
class XmlTvChannel {
  final String id;
  final String? displayName;
  final String? iconUrl;

  const XmlTvChannel({
    required this.id,
    this.displayName,
    this.iconUrl,
  });
}

class XmlTvProgramme {
  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? iconUrl;

  const XmlTvProgramme({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
    this.iconUrl,
  });

  bool contains(DateTime t) =>
      !t.isBefore(start) && t.isBefore(stop);

  Map<String, dynamic> toJson() => {
        'c': channelId,
        'a': start.toUtc().millisecondsSinceEpoch,
        'b': stop.toUtc().millisecondsSinceEpoch,
        't': title,
        if (description != null && description!.isNotEmpty) 'd': description,
        if (iconUrl != null && iconUrl!.isNotEmpty) 'i': iconUrl,
      };

  factory XmlTvProgramme.fromJson(Map<String, dynamic> json) {
    return XmlTvProgramme(
      channelId: json['c'] as String? ?? '',
      start: DateTime.fromMillisecondsSinceEpoch(
        json['a'] as int? ?? 0,
        isUtc: true,
      ),
      stop: DateTime.fromMillisecondsSinceEpoch(
        json['b'] as int? ?? 0,
        isUtc: true,
      ),
      title: json['t'] as String? ?? '',
      description: json['d'] as String?,
      iconUrl: json['i'] as String?,
    );
  }
}

/// Honest now/next pair from XMLTV (null fields stay hidden in UI).
class XmlTvNowNext {
  final String epgChannelId;
  final XmlTvProgramme now;
  final XmlTvProgramme? next;
  final double matchConfidence;

  const XmlTvNowNext({
    required this.epgChannelId,
    required this.now,
    this.next,
    this.matchConfidence = 1.0,
  });
}
