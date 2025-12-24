import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';

@JsonSerializable()
class Note {
  final String id;
  final String scribbleData; // JSON string from Scribble
  final String? screenshotPath;

  Note({
    required this.id,
    required this.scribbleData,
    this.screenshotPath,
  });

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
  Map<String, dynamic> toJson() => _$NoteToJson(this);
}
