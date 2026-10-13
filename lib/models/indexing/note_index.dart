import 'dart:convert';
import 'indexed_region.dart';

class IndexedPage {
  final int number;
  final String title;
  final String text;
  final String summary;
  final List<String> keywords;
  final List<IndexedRegion> regions;
  final bool isFinished;
  bool get needsReview => regions.any((region) => region.needsReview);
  const IndexedPage({
    required this.number,
    required this.title,
    required this.text,
    required this.summary,
    required this.keywords,
    this.regions = const [],
    this.isFinished = true,
  });

  factory IndexedPage.fromJson(Map<String, dynamic> json) => IndexedPage(
    number: (json['number'] as num).toInt(),
    isFinished: json['isFinished'] as bool? ?? true,
    title: json['title'] as String,
    text: json['text'] as String,
    summary: json['summary'] as String,
    keywords: (json['keywords'] as List).cast<String>(),
    regions: (json['regions'] as List? ?? [])
        .map(
          (region) => IndexedRegion.fromJson(Map<String, dynamic>.from(region)),
        )
        .toList(),
  );

  factory IndexedPage.fromModel(int number, String response) {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start < 0 || end < start) {
      throw const FormatException(
        'The local model did not return an annotation',
      );
    }
    final json =
        jsonDecode(response.substring(start, end + 1)) as Map<String, dynamic>;
    // Require a transcript instead of silently indexing an invented summary.
    if (json['title'] is! String ||
        json['text'] is! String ||
        json['summary'] is! String ||
        json['keywords'] is! List ||
        !(json['keywords'] as List).every((item) => item is String)) {
      throw const FormatException(
        'The local model returned an incomplete annotation',
      );
    }
    return IndexedPage.fromJson({...json, 'number': number});
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'text': text,
    'summary': summary,
    'keywords': keywords,
    'regions': regions.map((region) => region.toJson()).toList(),
    'isFinished': isFinished,
  };

  String get searchableText => '$title\n$text\n$summary\n${keywords.join(' ')}';
}

class NoteIndex {
  static const version = 2;
  final String noteId;
  final String fingerprint;
  final String model;
  final int pageCount;
  final List<IndexedPage> pages;
  final bool complete;
  const NoteIndex({
    required this.noteId,
    required this.fingerprint,
    required this.model,
    required this.pageCount,
    required this.pages,
    required this.complete,
  });

  bool get needsReview => pages.any((page) => page.needsReview);

  String get title => pages.isEmpty ? 'Unindexed note' : pages.first.title;
  String get searchableText =>
      pages.map((page) => page.searchableText).join('\n');
  String get context => pages
      .map(
        (page) =>
            'Page ${page.number}: ${page.title}\n${page.text}\nSummary: ${page.summary}',
      )
      .join('\n\n');

  Map<String, dynamic> toJson() => {
    'version': version,
    'noteId': noteId,
    'fingerprint': fingerprint,
    'model': model,
    'pageCount': pageCount,
    'pages': pages.map((page) => page.toJson()).toList(),
    'complete': complete,
  };

  factory NoteIndex.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version) {
      throw const FormatException('Unsupported index version');
    }
    return NoteIndex(
      noteId: json['noteId'] as String,
      fingerprint: json['fingerprint'] as String,
      model: json['model'] as String,
      pageCount: (json['pageCount'] as num).toInt(),
      pages: (json['pages'] as List)
          .map((page) => IndexedPage.fromJson(Map<String, dynamic>.from(page)))
          .toList(),
      complete: json['complete'] as bool,
    );
  }
}
