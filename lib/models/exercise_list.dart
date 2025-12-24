import 'package:json_annotation/json_annotation.dart';
import 'selection.dart';

part 'exercise_list.g.dart';

@JsonSerializable()
class ExerciseList {
  final String id;
  final String name;
  final String pdfPath;
  final List<Selection> selections;

  ExerciseList({
    required this.id,
    required this.name,
    required this.pdfPath,
    this.selections = const [],
  });

  factory ExerciseList.fromJson(Map<String, dynamic> json) => _$ExerciseListFromJson(json);
  Map<String, dynamic> toJson() => _$ExerciseListToJson(this);

  ExerciseList copyWith({
    String? name,
    List<Selection>? selections,
  }) {
    return ExerciseList(
      id: id,
      name: name ?? this.name,
      pdfPath: pdfPath,
      selections: selections ?? this.selections,
    );
  }
}
