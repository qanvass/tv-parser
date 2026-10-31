/// Keeps one copy of repeated cover and category strings inside a single
/// ingest batch. Cleared when that batch is queued so the isolate does not
/// retain the catalog.
class CatalogStringPool {
  final Map<String, String> _values = {};

  String intern(String value) {
    final existing = _values[value];
    if (existing != null) return existing;
    _values[value] = value;
    return value;
  }

  String? internNullable(String? value) {
    if (value == null) return null;
    return intern(value);
  }

  void clear() => _values.clear();
}
