import 'dart:convert';

import 'catalog_kind.dart';
import 'catalog_row_codec.dart';
import 'catalog_string_pool.dart';

class CatalogJsonException implements Exception {
  final String message;

  const CatalogJsonException(this.message);

  @override
  String toString() => message;
}

class CatalogBatch {
  final int startIndex;
  final List<Map<String, Object?>> rows;

  const CatalogBatch({required this.startIndex, required this.rows});
}

/// Pull parser for a JSON array of catalog objects.
///
/// It keeps the current object and one batch. After a batch is queued the
/// string pool is cleared. Callers must [takeBatch] before the next [pump]
/// can queue another batch.
class CatalogJsonScanner {
  CatalogJsonScanner({
    required this.kind,
    this.batchSize = defaultBatchSize,
  }) : assert(batchSize > 0);

  static const int defaultBatchSize = 400;

  final CatalogKind kind;
  final int batchSize;
  final CatalogStringPool pool = CatalogStringPool();

  String _buffer = '';
  int _i = 0;
  int _depth = 0;
  bool _inString = false;
  bool _escape = false;
  bool _capturing = false;
  final StringBuffer _object = StringBuffer();
  final List<Map<String, Object?>> _batch = [];
  int _rowIndex = 0;
  int _batchStart = 0;
  CatalogBatch? _ready;

  bool get hasBatch => _ready != null;

  void addText(String chunk) {
    if (chunk.isEmpty) return;
    if (_buffer.isEmpty && _i == 0 && chunk.startsWith('\uFEFF')) {
      chunk = chunk.substring(1);
    }
    _buffer += chunk;
  }

  /// Parse until one batch is queued, or the buffered text is exhausted.
  /// At end of input, also queue a short final batch and drop the string pool.
  void pump({required bool endOfInput}) {
    if (_ready != null) return;
    _parse();
    if (_ready != null) return;
    if (!endOfInput) return;
    if (_inString || _capturing || _depth != 0) {
      throw const CatalogJsonException('catalog json ended early');
    }
    if (_batch.isNotEmpty) {
      _queueBatch();
      return;
    }
    pool.clear();
    _buffer = '';
    _i = 0;
  }

  CatalogBatch takeBatch() {
    final batch = _ready;
    if (batch == null) {
      throw const CatalogJsonException('catalog batch missing');
    }
    _ready = null;
    return batch;
  }

  void _parse() {
    final n = _buffer.length;
    while (_i < n) {
      if (_ready != null) break;
      final ch = _buffer[_i];
      _i++;
      if (_inString) {
        if (_capturing) _object.write(ch);
        if (_escape) {
          _escape = false;
        } else if (ch == r'\') {
          _escape = true;
        } else if (ch == '"') {
          _inString = false;
        }
        continue;
      }
      if (ch == '"') {
        _inString = true;
        if (_capturing) _object.write(ch);
        continue;
      }
      if (ch == '{') {
        if (_depth == 0) {
          _capturing = true;
          _object.clear();
        }
        _depth++;
        if (_capturing) _object.write(ch);
        continue;
      }
      if (ch == '}') {
        if (!_capturing || _depth == 0) {
          throw const CatalogJsonException('catalog json has an extra brace');
        }
        _object.write(ch);
        _depth--;
        if (_depth == 0) {
          _emitObject();
          _capturing = false;
        }
        continue;
      }
      if (_capturing) _object.write(ch);
    }
    _compact();
  }

  void _emitObject() {
    final text = _object.toString();
    _object.clear();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw CatalogJsonException('catalog object failed at index $_rowIndex');
    }
    if (decoded is! Map) {
      throw CatalogJsonException('catalog object failed at index $_rowIndex');
    }
    _batch.add(
      CatalogRowCodec.encode(
        kind,
        _rowIndex,
        Map<String, dynamic>.from(decoded),
        pool,
      ),
    );
    _rowIndex++;
    if (_batch.length >= batchSize) {
      _queueBatch();
    }
  }

  void _queueBatch() {
    if (_batch.isEmpty) return;
    if (_ready != null) {
      throw const CatalogJsonException('catalog batch was not taken');
    }
    final rows = [for (final row in _batch) row];
    _batch.clear();
    pool.clear();
    _ready = CatalogBatch(startIndex: _batchStart, rows: rows);
    _batchStart = _rowIndex;
  }

  void _compact() {
    if (_i < 8192) return;
    _buffer = _buffer.substring(_i);
    _i = 0;
  }
}
