class IndexedRegion {
  final int number;
  final String text;
  final List<double> bounds;
  final int expectedLines;
  final bool needsReview;
  const IndexedRegion({
    required this.number,
    required this.text,
    required this.bounds,
    required this.expectedLines,
    required this.needsReview,
  });

  factory IndexedRegion.fromTranscript({
    required int number,
    required String text,
    required List<double> bounds,
    required int expectedLines,
  }) {
    final actualLines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    return IndexedRegion(
      number: number,
      text: text,
      bounds: bounds,
      expectedLines: expectedLines,
      needsReview:
          text.trim().isEmpty ||
          text.contains('[illegible]') ||
          (expectedLines >= 3 && actualLines < (expectedLines * 0.6).ceil()),
    );
  }
  Map<String, dynamic> toJson() => {
    'number': number,
    'text': text,
    'bounds': bounds,
    'expectedLines': expectedLines,
    'needsReview': needsReview,
  };
  factory IndexedRegion.fromJson(Map<String, dynamic> json) => IndexedRegion(
    number: (json['number'] as num).toInt(),
    text: json['text'] as String,
    bounds: (json['bounds'] as List)
        .map((value) => (value as num).toDouble())
        .toList(),
    expectedLines: (json['expectedLines'] as num).toInt(),
    needsReview: json['needsReview'] as bool,
  );
}
