// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Folder _$FolderFromJson(Map<String, dynamic> json) => Folder(
  id: json['id'] as String,
  name: json['name'] as String,
  exerciseLists:
      (json['exerciseLists'] as List<dynamic>?)
          ?.map((e) => ExerciseList.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  notes:
      (json['notes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, Note.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
);

Map<String, dynamic> _$FolderToJson(Folder instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'exerciseLists': instance.exerciseLists,
  'notes': instance.notes,
};
