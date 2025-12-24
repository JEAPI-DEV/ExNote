// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExerciseList _$ExerciseListFromJson(Map<String, dynamic> json) => ExerciseList(
  id: json['id'] as String,
  name: json['name'] as String,
  pdfPath: json['pdfPath'] as String,
  selections:
      (json['selections'] as List<dynamic>?)
          ?.map((e) => Selection.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ExerciseListToJson(ExerciseList instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'pdfPath': instance.pdfPath,
      'selections': instance.selections,
    };
