import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../repository/api/api.dart';
import '../../../repository/models/channel_live.dart';
import '../../../repository/models/epg.dart';

/// Lightweight now/next EPG strip for live playback / peeks.
class TvEpgPeek extends StatefulWidget {
  final String? streamId;
  final String? tvgId;
  final String? channelName;
  final bool compact;

  const TvEpgPeek({
    super.key,
    this.streamId,
    this.tvgId,
    this.channelName,
    this.compact = true,
  });

  @override
  State<TvEpgPeek> createState() => _TvEpgPeekState();
}

class _TvEpgPeekState extends State<TvEpgPeek> {
  String? _now;
  String? _next;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    XmlTvRepository.instance.addListener(_onXmlTv);
    _load();
  }

  @override
  void dispose() {
    XmlTvRepository.instance.removeListener(_onXmlTv);
    super.dispose();
  }

  void _onXmlTv() {
    if (mounted) _load();
  }

  @override
  void didUpdateWidget(covariant TvEpgPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamId != widget.streamId ||
        oldWidget.tvgId != widget.tvgId ||
        oldWidget.channelName != widget.channelName) {
      _load();
    }
  }

  Future<void> _load() async {
    final xml = XmlTvRepository.instance.nowNext(
      tvgId: widget.tvgId,
      channelName: widget.channelName,
      streamId: widget.streamId,
    );
    if (xml != null) {
      if (!mounted) return;
      setState(() {
        _now = xml.now.title;
        _next = xml.next?.title;
        _loading = false;
      });
      return;
    }

    final id = widget.streamId?.trim();
    if (id == null || id.isEmpty || id.contains('://')) {
      if (!mounted) return;
      setState(() {
        _now = null;
        _next = null;
        _loading = XmlTvRepository.instance.isLoading;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final listings = await IpTvApi.getEPGbyStreamId(id);
      if (!mounted) return;
      final decoded = listings
          .map(_decodeTitle)
          .where((t) => t != null && t.isNotEmpty)
          .cast<String>()
          .toList();
      setState(() {
        _now = decoded.isNotEmpty ? decoded.first : null;
        _next = decoded.length > 1 ? decoded[1] : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _now = null;
          _next = null;
          _loading = false;
        });
      }
    }
  }

  String? _decodeTitle(EpgModel epg) {
    final raw = epg.title;
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    try {
      if (_looksBase64(raw)) {
        return utf8.decode(base64.decode(raw));
      }
    } catch (_) {}
    return raw;
  }

  bool _looksBase64(String s) {
    if (s.length < 8 || s.length % 4 != 0) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(s);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Text(
        'Loading guide…',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: widget.compact ? 12 : 14,
        ),
      );
    }
    if (_now == null && _next == null) {
      // Quiet honest state: the guide was attempted but no source had a
      // current programme (dead/stale feed). Never invent listings.
      if (XmlTvRepository.instance.status == XmlTvStatus.unavailable) {
        return Text(
          'Guide unavailable',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.32),
            fontSize: widget.compact ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_now != null)
          Text(
            'Now: $_now',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: widget.compact ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (_next != null) ...[
          const SizedBox(height: 2),
          Text(
            'Next: $_next',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: widget.compact ? 11 : 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Extract Xtream stream id from a typical live URL path.
String? extractStreamIdFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments;
    if (seg.isEmpty) return null;
    final last = seg.last.replaceAll(RegExp(r'\.(ts|m3u8|mp4)$'), '');
    if (RegExp(r'^\d+$').hasMatch(last)) return last;
    return null;
  } catch (_) {
    return null;
  }
}

/// Channel the live-player heart should save.
///
/// A numeric path id is used when the catalog has that row. Otherwise the
/// playback link is matched to [ChannelLive.directSource]. If neither hits,
/// the link itself is the id so the press still saves.
ChannelLive resolveLiveFavoriteChannel({
  required String link,
  String? streamId,
  String? title,
  String? streamIcon,
  required List<ChannelLive> catalog,
}) {
  final explicit = streamId?.trim();
  final extracted = extractStreamIdFromUrl(link);
  final wanted = (explicit != null && explicit.isNotEmpty)
      ? explicit
      : extracted;
  if (wanted != null && wanted.isNotEmpty) {
    for (final channel in catalog) {
      if ((channel.streamId ?? '').trim() == wanted) return channel;
    }
  }
  final trimmed = link.trim();
  if (trimmed.isNotEmpty) {
    for (final channel in catalog) {
      final direct = (channel.directSource ?? '').trim();
      if (direct.isNotEmpty && direct == trimmed) return channel;
    }
  }
  final id = (wanted != null && wanted.isNotEmpty)
      ? wanted
      : trimmed;
  return ChannelLive(
    streamId: id.isEmpty ? null : id,
    name: title,
    streamIcon: streamIcon,
    directSource: trimmed.isEmpty ? null : trimmed,
  );
}

bool sameLiveFavorite(ChannelLive saved, ChannelLive target) {
  final savedId = saved.streamId?.trim() ?? '';
  final targetId = target.streamId?.trim() ?? '';
  if (savedId.isNotEmpty && savedId == targetId) return true;
  final savedLink = saved.directSource?.trim() ?? '';
  final targetLink = target.directSource?.trim() ?? '';
  return savedLink.isNotEmpty && savedLink == targetLink;
}
