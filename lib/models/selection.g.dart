// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Selection _$SelectionFromJson(Map<String, dynamic> json) => Selection(
  id: json['id'] as String,
  left: (json['left'] as num).toDouble(),
  top: (json['top'] as num).toDouble(),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  pageIndex: (json['pageIndex'] as num).toInt(),
  noteId: json['noteId'] as String,
  screenshotPath: json['screenshotPath'] as String?,
);

Map<String, dynamic> _$SelectionToJson(Selection instance) => <String, dynamic>{
  'id': instance.id,
  'left': instance.left,
  'top': instance.top,
  'width': instance.width,
  'height': instance.height,
  'pageIndex': instance.pageIndex,
  'noteId': instance.noteId,
  'screenshotPath': instance.screenshotPath,
};
