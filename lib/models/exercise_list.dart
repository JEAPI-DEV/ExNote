import 'package:json_annotation/json_annotation.dart';
import 'selection.dart';
import 'pdf_annotation.dart';

part 'exercise_list.g.dart';

@JsonSerializable()
class ExerciseList {
  final String id;
  final String name;
  final String pdfPath;
  final List<Selection> selections;
  final List<PdfAnnotation> annotations;

  ExerciseList({
    required this.id,
    required this.name,
    required this.pdfPath,
    this.selections = const [],
    this.annotations = const [],
  });

  factory ExerciseList.fromJson(Map<String, dynamic> json) => _$ExerciseListFromJson(json);
  Map<String, dynamic> toJson() => _$ExerciseListToJson(this);

  ExerciseList copyWith({
    String? name,
    List<Selection>? selections,
    List<PdfAnnotation>? annotations,
  }) {
    return ExerciseList(
      id: id,
      name: name ?? this.name,
      pdfPath: pdfPath,
      selections: selections ?? this.selections,
      annotations: annotations ?? this.annotations,
    );
  }
}
