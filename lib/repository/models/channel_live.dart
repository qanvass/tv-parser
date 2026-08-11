class ChannelLive {
  final String? num;
  final String? name;
  final String? streamType;
  final String? streamId;
  final String? streamIcon;
  final dynamic epgChannelId;
  final String? added;
  final String? isAdult;
  final String? categoryId;
  final String? customSid;
  final String? tvArchive;
  final String? directSource;
  final String? tvArchiveDuration;

  const ChannelLive({
    this.num,
    this.name,
    this.streamType,
    this.streamId,
    this.streamIcon,
    this.epgChannelId,
    this.added,
    this.isAdult,
    this.categoryId,
    this.customSid,
    this.tvArchive,
    this.directSource,
    this.tvArchiveDuration,
  });

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }

  ChannelLive.fromJson(Map<String, dynamic> json)
      : num = _str(json['num']),
        name = _str(json['name']),
        streamType = _str(json['stream_type']),
        streamId = _str(json['stream_id']),
        streamIcon = _str(json['stream_icon']),
        epgChannelId = _str(json['epg_channel_id']),
        added = _str(json['added']),
        isAdult = _str(json['is_adult']),
        categoryId = _str(json['category_id']),
        customSid = _str(json['custom_sid']),
        tvArchive = _str(json['tv_archive']),
        directSource = _str(json['direct_source']),
        tvArchiveDuration = _str(json['tv_archive_duration']);

  Map<String, dynamic> toJson() => {
        'num': num,
        'name': name,
        'stream_type': streamType,
        'stream_id': streamId,
        'stream_icon': streamIcon,
        'epg_channel_id': epgChannelId,
        'added': added,
        'is_adult': isAdult,
        'category_id': categoryId,
        'custom_sid': customSid,
        'tv_archive': tvArchive,
        'direct_source': directSource,
        'tv_archive_duration': tvArchiveDuration
      };
}
