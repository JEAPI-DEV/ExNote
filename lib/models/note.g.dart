// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Note _$NoteFromJson(Map<String, dynamic> json) => Note(
  id: json['id'] as String,
  scribbleData: json['scribbleData'] as String,
  screenshotPath: json['screenshotPath'] as String?,
);

Map<String, dynamic> _$NoteToJson(Note instance) => <String, dynamic>{
  'id': instance.id,
  'scribbleData': instance.scribbleData,
  'screenshotPath': instance.screenshotPath,
};
