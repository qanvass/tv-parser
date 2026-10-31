enum CatalogKind {
  series('series'),
  movie('movie'),
  live('live');

  const CatalogKind(this.storageKey);

  final String storageKey;

  static CatalogKind fromStorage(String key) {
    for (final kind in CatalogKind.values) {
      if (kind.storageKey == key) return kind;
    }
    throw ArgumentError('Unknown catalog kind');
  }
}
