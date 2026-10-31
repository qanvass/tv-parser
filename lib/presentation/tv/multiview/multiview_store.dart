import 'package:get_storage/get_storage.dart';

/// Four live stream ids for the multiview grid.
///
/// Stores ids only (`m3u_stream_N` or the catalog id). Playback URLs stay in
/// the catalog and are resolved when a tile starts.
class MultiviewStore {
  MultiviewStore._();

  static const int slotCount = 4;
  static const String storageKey = 'multiview_live_stream_ids';

  static List<String?> read() {
    final out = List<String?>.filled(slotCount, null);
    try {
      final raw = GetStorage('preferences').read(storageKey);
      if (raw is! List) return out;
      for (var i = 0; i < slotCount && i < raw.length; i++) {
        final id = raw[i]?.toString().trim() ?? '';
        if (id.isNotEmpty) out[i] = id;
      }
    } catch (_) {}
    return out;
  }

  static void write(List<String?> ids) {
    final payload = List<String>.generate(slotCount, (i) {
      if (i >= ids.length) return '';
      final id = ids[i]?.trim() ?? '';
      return id;
    });
    try {
      GetStorage('preferences').write(storageKey, payload);
    } catch (_) {}
  }
}
