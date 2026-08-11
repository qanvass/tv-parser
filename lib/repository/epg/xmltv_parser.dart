import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'xmltv_models.dart';
import 'xmltv_time.dart';

/// Streaming XMLTV extract (channel ids + windowed programmes).
///
/// Clean-room parser for standard XMLTV. Does not invent titles.
class XmlTvParser {
  /// Keep programmes overlapping [windowStart, windowEnd).
  static XmlTvParseResult parseXml(
    String xml, {
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final channels = <String, XmlTvChannel>{};
    final programmes = <String, List<XmlTvProgramme>>{};

    for (final m in _channelRe.allMatches(xml)) {
      final block = m.group(0)!;
      final id = _attr(block, 'id');
      if (id == null || id.isEmpty) continue;
      channels[id] = XmlTvChannel(
        id: id,
        displayName: _tagText(block, 'display-name'),
        iconUrl: _iconSrc(block),
      );
    }

    for (final m in _programmeRe.allMatches(xml)) {
      final block = m.group(0)!;
      final channelId = _attr(block, 'channel');
      if (channelId == null || channelId.isEmpty) continue;
      final start = XmlTvTime.parse(_attr(block, 'start'));
      final stop = XmlTvTime.parse(_attr(block, 'stop'));
      if (start == null || stop == null) continue;
      if (stop.isBefore(windowStart) || !start.isBefore(windowEnd)) {
        continue;
      }
      final title = _tagText(block, 'title');
      if (title == null || title.isEmpty) continue;
      programmes.putIfAbsent(channelId, () => []).add(
            XmlTvProgramme(
              channelId: channelId,
              start: start,
              stop: stop,
              title: title,
              description: _tagText(block, 'desc'),
              iconUrl: _iconSrc(block),
            ),
          );
    }

    for (final list in programmes.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    return XmlTvParseResult(channels: channels, programmes: programmes);
  }

  /// Gunzip [bytes] then parse. Safe to call from an isolate.
  static XmlTvParseResult parseGzipBytes(
    Uint8List bytes, {
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final xml = utf8.decode(gzip.decode(bytes), allowMalformed: true);
    return parseXml(xml, windowStart: windowStart, windowEnd: windowEnd);
  }

  static final RegExp _channelRe = RegExp(
    r'<channel\b[^>]*>[\s\S]*?</channel>',
    caseSensitive: false,
  );
  static final RegExp _programmeRe = RegExp(
    r'<programme\b[^>]*>[\s\S]*?</programme>',
    caseSensitive: false,
  );
  static final RegExp _attrRe = RegExp(
    r'''([A-Za-z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')''',
  );

  static String? _attr(String block, String name) {
    // Only scan the opening tag.
    final gt = block.indexOf('>');
    final head = gt > 0 ? block.substring(0, gt) : block;
    for (final m in _attrRe.allMatches(head)) {
      if (m.group(1)?.toLowerCase() == name.toLowerCase()) {
        return _unescape(m.group(2) ?? m.group(3) ?? '');
      }
    }
    return null;
  }

  static String? _tagText(String block, String tag) {
    final re = RegExp(
      '<$tag\\b[^>]*>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    final m = re.firstMatch(block);
    if (m == null) return null;
    final text = _unescape(_stripTags(m.group(1) ?? '')).trim();
    return text.isEmpty ? null : text;
  }

  static String? _iconSrc(String block) {
    final re = RegExp(
      r'''<icon\b[^>]*\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)')''',
      caseSensitive: false,
    );
    final m = re.firstMatch(block);
    final src = (m?.group(1) ?? m?.group(2) ?? '').trim();
    return src.isEmpty ? null : src;
  }

  static String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

  static String _unescape(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) {
            final n = int.tryParse(m.group(1)!);
            if (n == null) return m.group(0)!;
            return String.fromCharCode(n);
          },
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9A-Fa-f]+);'),
          (m) {
            final n = int.tryParse(m.group(1)!, radix: 16);
            if (n == null) return m.group(0)!;
            return String.fromCharCode(n);
          },
        );
  }
}

class XmlTvParseResult {
  final Map<String, XmlTvChannel> channels;
  final Map<String, List<XmlTvProgramme>> programmes;

  const XmlTvParseResult({
    required this.channels,
    required this.programmes,
  });

  int get channelCount => channels.length;
  int get programmeCount =>
      programmes.values.fold<int>(0, (n, list) => n + list.length);
}
