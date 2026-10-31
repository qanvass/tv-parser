import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// VOD masters list up to dozens of subtitle languages and extra audio groups.
/// VLC opens every one of them before the first frame, which took 20-40s and on
/// some titles never finished (black screen). This hands VLC a local copy with
/// the video variants and one audio group only.
class HlsVodPlaylist {
  HlsVodPlaylist._();

  static const int _maxBytes = 256 * 1024;
  static final RegExp _uriAttr = RegExp(r'URI="([^"]*)"');
  static final RegExp _audioAttr = RegExp(r'[:,]AUDIO="([^"]*)"');
  static final RegExp _groupAttr = RegExp(r'GROUP-ID="([^"]*)"');
  static final RegExp _subtitlesAttr = RegExp(
    r'(?<=:)SUBTITLES="[^"]*",?|,SUBTITLES="[^"]*"',
  );

  /// Trimmed master text, or null when [body] is not an HLS master with
  /// anything to trim (plain files and media playlists play as they are).
  @visibleForTesting
  static String? trim(String body, Uri base) {
    if (!body.trimLeft().startsWith('#EXTM3U')) return null;
    final lines = const LineSplitter().convert(body);
    if (!lines.any((l) => l.startsWith('#EXT-X-STREAM-INF'))) return null;
    if (!lines.any((l) => l.startsWith('#EXT-X-MEDIA:'))) return null;

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
    if (!out.any((l) => l.startsWith('#EXT-X-STREAM-INF'))) return null;
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
