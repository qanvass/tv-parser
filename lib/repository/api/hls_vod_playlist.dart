import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

/// VOD masters list up to dozens of subtitle languages and extra audio groups.
/// VLC opens every one of them before the first frame, which took 20-40s and on
/// some titles never finished (black screen). This hands VLC a local copy with
/// one audio group and, when a quality is chosen, a single video variant.
///
/// One variant because VLC otherwise climbs the ladder while playing (480p,
/// 4K, 1440p, 4K in the first 25 s on the Chromecast) and every step rebuilds
/// the decoder, which the viewer sees as buffering.
class HlsVodPlaylist {
  HlsVodPlaylist._();

  /// Selectable quality caps, by video height. First is the default.
  static const List<int> qualityHeights = [1080, 2160, 720];
  static const String _qualityKey = 'vod_max_height';

  /// Tallest video the viewer wants for movies and episodes.
  static int get maxHeightPref {
    try {
      final v = GetStorage('preferences').read(_qualityKey);
      if (v is int && qualityHeights.contains(v)) return v;
    } catch (_) {}
    return qualityHeights.first;
  }

  static String qualityLabel(int height) =>
      height >= 2160 ? '4K' : '${height}p';

  /// Moves to the next quality cap and returns it.
  static int cycleQuality() {
    final i = qualityHeights.indexOf(maxHeightPref);
    final next = qualityHeights[(i + 1) % qualityHeights.length];
    try {
      GetStorage('preferences').write(_qualityKey, next);
    } catch (_) {}
    return next;
  }

  static final RegExp _resolutionAttr = RegExp(r'RESOLUTION=(\d+)x(\d+)');
  static final RegExp _bandwidthAttr = RegExp(r'[:,]BANDWIDTH=(\d+)');

  /// Index in [infLines] of the variant to keep: the tallest one that fits
  /// [maxHeight], highest bitrate on a tie. When none fits, the shortest.
  /// Masters without RESOLUTION keep their highest bitrate.
  @visibleForTesting
  static int pickVariant(List<String> infLines, int maxHeight) {
    int heightOf(String l) =>
        int.tryParse(_resolutionAttr.firstMatch(l)?.group(2) ?? '') ?? 0;
    int rateOf(String l) =>
        int.tryParse(_bandwidthAttr.firstMatch(l)?.group(1) ?? '') ?? 0;
    var best = 0;
    for (var i = 1; i < infLines.length; i++) {
      final h = heightOf(infLines[i]);
      final bh = heightOf(infLines[best]);
      final fits = h <= maxHeight;
      final bestFits = bh <= maxHeight;
      final bool better;
      if (fits != bestFits) {
        better = fits;
      } else if (h != bh) {
        better = fits ? h > bh : h < bh;
      } else {
        better = rateOf(infLines[i]) > rateOf(infLines[best]);
      }
      if (better) best = i;
    }
    return best;
  }

  static const int _maxBytes = 256 * 1024;
  static final RegExp _uriAttr = RegExp(r'URI="([^"]*)"');
  static final RegExp _audioAttr = RegExp(r'[:,]AUDIO="([^"]*)"');
  static final RegExp _groupAttr = RegExp(r'GROUP-ID="([^"]*)"');
  static final RegExp _subtitlesAttr = RegExp(
    r'(?<=:)SUBTITLES="[^"]*",?|,SUBTITLES="[^"]*"',
  );

  /// Trimmed master text, or null when [body] is not an HLS master with
  /// anything to trim (plain files and media playlists play as they are).
  /// With [maxHeight], only the variant chosen by [pickVariant] is kept.
  @visibleForTesting
  static String? trim(String body, Uri base, {int? maxHeight}) {
    if (!body.trimLeft().startsWith('#EXTM3U')) return null;
    final lines = const LineSplitter().convert(body);
    final variantCount = lines
        .where((l) => l.startsWith('#EXT-X-STREAM-INF'))
        .length;
    if (variantCount == 0) return null;
    final hasMedia = lines.any((l) => l.startsWith('#EXT-X-MEDIA:'));
    if (!hasMedia && (maxHeight == null || variantCount < 2)) return null;

    String? audioGroup;
    for (final l in lines) {
      if (l.startsWith('#EXT-X-MEDIA:') && l.contains('TYPE=AUDIO')) {
        audioGroup = _groupAttr.firstMatch(l)?.group(1);
        break;
      }
    }

    final out = <String>[];
    var audioKept = false;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.startsWith('#EXT-X-I-FRAME-STREAM-INF')) continue;
      if (l.startsWith('#EXT-X-MEDIA:')) {
        if (!l.contains('TYPE=AUDIO') || audioKept) continue;
        audioKept = true;
        out.add(
          l.replaceAllMapped(
            _uriAttr,
            (m) => 'URI="${base.resolve(m.group(1)!)}"',
          ),
        );
        continue;
      }
      if (l.startsWith('#EXT-X-STREAM-INF')) {
        final group = _audioAttr.firstMatch(l)?.group(1);
        final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
        i++;
        if (group != null && group != audioGroup) continue;
        if (next.isEmpty) continue;
        out.add(l.replaceAll(_subtitlesAttr, ''));
        out.add(base.resolve(next).toString());
        continue;
      }
      out.add(l);
    }
    final infAt = <int>[
      for (var i = 0; i < out.length; i++)
        if (out[i].startsWith('#EXT-X-STREAM-INF')) i,
    ];
    if (infAt.isEmpty) return null;
    if (maxHeight != null && infAt.length > 1) {
      final keep =
          infAt[pickVariant([for (final i in infAt) out[i]], maxHeight)];
      // Each variant is its tag line plus the address line after it.
      for (final i in infAt.reversed) {
        if (i != keep) out.removeRange(i, i + 2);
      }
    }
    return '${out.join('\n')}\n';
  }

  /// URL for VLC: a local trimmed master when possible, else [url] unchanged.
  /// Never throws; any failure falls back to the original link.
  static Future<String> prepare(String url) async {
    if (!url.startsWith('http')) return url;
    final cancel = CancelToken();
    try {
      final res = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'User-Agent': 'VLC/3.0.21 LibVLC/3.0.21'},
          responseType: ResponseType.stream,
        ),
      ).get<ResponseBody>(url, cancelToken: cancel);
      final bytes = BytesBuilder(copy: false);
      var first = true;
      await for (final chunk in res.data!.stream) {
        if (first) {
          first = false;
          // Direct media files: never download them here.
          final head = utf8.decode(
            chunk.take(32).toList(),
            allowMalformed: true,
          );
          if (!head.trimLeft().startsWith('#EXTM3U')) {
            cancel.cancel();
            return url;
          }
        }
        bytes.add(chunk);
        if (bytes.length > _maxBytes) {
          cancel.cancel();
          return url;
        }
      }
      final trimmed = trim(
        utf8.decode(bytes.takeBytes(), allowMalformed: true),
        res.realUri,
        maxHeight: maxHeightPref,
      );
      if (trimmed == null) return url;
      final dir = await getTemporaryDirectory();
      final name = sha1.convert(utf8.encode(url)).toString();
      final file = File('${dir.path}/vod_$name.m3u8');
      await file.writeAsString(trimmed, flush: true);
      return file.uri.toString();
    } catch (e) {
      if (!cancel.isCancelled) cancel.cancel();
      debugPrint('[VOD_PLAYLIST] using original link: ${e.runtimeType}');
      return url;
    }
  }
}
