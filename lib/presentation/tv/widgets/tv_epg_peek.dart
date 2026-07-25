import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../repository/api/api.dart';
import '../../../repository/models/epg.dart';

/// Lightweight now/next EPG strip for live playback / peeks.
class TvEpgPeek extends StatefulWidget {
  final String? streamId;
  final bool compact;

  const TvEpgPeek({super.key, this.streamId, this.compact = true});

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
    _load();
  }

  @override
  void didUpdateWidget(covariant TvEpgPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamId != widget.streamId) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.streamId?.trim();
    if (id == null || id.isEmpty || id.contains('://')) {
      setState(() {
        _now = null;
        _next = null;
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
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: widget.compact ? 12 : 14,
        ),
      );
    }
    if (_now == null && _next == null) {
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
