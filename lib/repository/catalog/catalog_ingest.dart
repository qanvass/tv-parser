import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'catalog_json_scanner.dart';
import 'catalog_kind.dart';
import 'catalog_store.dart';

/// Streams a catalog JSON array into [CatalogStore] one batch at a time.
///
/// The parse isolate does not return the decoded list. The caller isolate
/// inserts the batch and drops it before the next batch is parsed.
class CatalogIngest {
  static const int chunkBytes = 32768;

  static Future<int> ingestFile({
    required CatalogStore store,
    required CatalogKind kind,
    required String path,
    int batchSize = CatalogJsonScanner.defaultBatchSize,
  }) {
    return store.serialize(
      () => _ingestFile(
        store: store,
        kind: kind,
        path: path,
        batchSize: batchSize,
      ),
    );
  }

  static Future<int> _ingestFile({
    required CatalogStore store,
    required CatalogKind kind,
    required String path,
    required int batchSize,
  }) async {
    final incoming = ReceivePort();
    final isolate = await Isolate.spawn(
      catalogIngestIsolateMain,
      incoming.sendPort,
      debugName: 'catalog-ingest',
    );
    try {
      final events = StreamIterator<dynamic>(incoming);
      if (!await events.moveNext()) {
        throw const CatalogJsonException('catalog ingest isolate ended');
      }
      final toIsolate = events.current as SendPort;
      toIsolate.send({
        'path': path,
        'kind': kind.storageKey,
        'batch': batchSize,
      });
      await store.beginReplace(kind);
      var total = 0;
      while (await events.moveNext()) {
        final message = events.current;
        if (message is Map && message['type'] == 'batch') {
          final rows = (message['rows'] as List)
              .map((row) => Map<String, Object?>.from(row as Map))
              .toList(growable: true);
          await store.addBatch(rows);
          total += rows.length;
          rows.clear();
          toIsolate.send('ack');
        } else if (message == 'done') {
          await store.commitReplace(kind, total);
          return total;
        } else if (message is Map && message['type'] == 'error') {
          await store.abortReplace(kind);
          throw const CatalogJsonException('catalog ingest failed');
        }
      }
      await store.abortReplace(kind);
      throw const CatalogJsonException('catalog ingest ended');
    } catch (error) {
      if (error is! CatalogJsonException) {
        try {
          await store.abortReplace(kind);
        } catch (_) {}
      }
      rethrow;
    } finally {
      isolate.kill(priority: Isolate.beforeNextEvent);
      incoming.close();
    }
  }
}

/// Isolate entry. Sends one batch, then waits, so the decoded batch can be
/// dropped before the next objects are parsed.
Future<void> catalogIngestIsolateMain(SendPort toMain) async {
  final fromMain = ReceivePort();
  toMain.send(fromMain.sendPort);
  final incoming = StreamIterator<dynamic>(fromMain);
  RandomAccessFile? input;
  try {
    if (!await incoming.moveNext() || incoming.current is! Map) {
      toMain.send({'type': 'error'});
      return;
    }
    final job = Map<String, Object?>.from(incoming.current as Map);
    final path = job['path'] as String?;
    final kindKey = job['kind'] as String?;
    final batchSize = job['batch'];
    if (path == null || kindKey == null || batchSize is! int || batchSize < 1) {
      toMain.send({'type': 'error'});
      return;
    }
    final scanner = CatalogJsonScanner(
      kind: CatalogKind.fromStorage(kindKey),
      batchSize: batchSize,
    );
    input = await File(path).open();
    final scratch = Uint8List(CatalogIngest.chunkBytes);
    final utf8Tail = _Utf8Tail();

    Future<void> emitReady() async {
      while (scanner.hasBatch) {
        final batch = scanner.takeBatch();
        toMain.send({
          'type': 'batch',
          'start': batch.startIndex,
          'rows': batch.rows,
        });
        if (!await incoming.moveNext()) {
          throw const CatalogJsonException('catalog ingest ack missing');
        }
        scanner.pump(endOfInput: false);
      }
    }

    while (true) {
      final n = await input.readInto(scratch);
      if (n <= 0) break;
      final text = utf8Tail.add(Uint8List.sublistView(scratch, 0, n));
      if (text.isEmpty) continue;
      scanner.addText(text);
      scanner.pump(endOfInput: false);
      await emitReady();
    }
    final tail = utf8Tail.finish();
    if (tail.isNotEmpty) scanner.addText(tail);
    scanner.pump(endOfInput: true);
    await emitReady();
    scanner.pump(endOfInput: true);
    await emitReady();
    toMain.send('done');
  } catch (_) {
    toMain.send({'type': 'error'});
  } finally {
    incoming.cancel();
    fromMain.close();
    await input?.close();
  }
}

class _Utf8Tail {
  final List<int> _partial = [];

  String add(List<int> chunk) {
    if (chunk.isEmpty && _partial.isEmpty) return '';
    _partial.addAll(chunk);
    var end = _partial.length;
    var index = end - 1;
    var continuations = 0;
    while (index >= 0 && (_partial[index] & 0xC0) == 0x80) {
      continuations++;
      index--;
    }
    if (index >= 0 && _partial[index] >= 0x80) {
      final lead = _partial[index];
      final need = lead >= 0xF0 ? 4 : lead >= 0xE0 ? 3 : lead >= 0xC0 ? 2 : 1;
      if (1 + continuations < need) end = index;
    } else if (index < 0 && continuations > 0) {
      end = 0;
    }
    if (end <= 0) return '';
    final text = _decode(_partial.sublist(0, end));
    _partial.removeRange(0, end);
    return text;
  }

  String finish() {
    if (_partial.isEmpty) return '';
    final text = _decode(_partial);
    _partial.clear();
    return text;
  }

  String _decode(List<int> bytes) => utf8.decode(bytes);
}
