import 'package:json_annotation/json_annotation.dart';

part 'pdf_annotation.g.dart';

/// An ink annotation drawn directly on a page of an exercise PDF.
///
/// The stroke data is stored as the serialized JSON of a `scribble` [Sketch],
/// in page-point coordinates, so it can be re-rendered at any display scale.
@JsonSerializable()
class PdfAnnotation {
  /// Zero-based index of the annotated page.
  final int pageIndex;

  /// Serialized `Sketch` JSON for this page.
  final String sketchJson;

  PdfAnnotation({required this.pageIndex, required this.sketchJson});

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) =>
      _$PdfAnnotationFromJson(json);

  Map<String, dynamic> toJson() => _$PdfAnnotationToJson(this);
}
