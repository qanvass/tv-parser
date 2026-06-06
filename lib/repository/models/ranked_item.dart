class RankedItem<T> {
  final T item;
  final double score;
  final double confidence;
  final List<String> reasons;
  final String contentType; // 'live', 'movie', 'series'
  final String sourceRow;

  RankedItem({
    required this.item,
    required this.score,
    required this.confidence,
    required this.reasons,
    required this.contentType,
    required this.sourceRow,
  });

  @override
  String toString() {
    return 'RankedItem(title: ${getItemTitle(item)}, score: $score, confidence: $confidence, contentType: $contentType, sourceRow: $sourceRow, reasons: $reasons)';
  }

  static String getItemTitle(dynamic item) {
    if (item == null) return 'Unknown';
    try {
      return item.name ?? item.title ?? 'No Title';
    } catch (_) {
      return 'No Title';
    }
  }
}
