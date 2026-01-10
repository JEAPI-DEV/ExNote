import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';

@JsonSerializable()
class Note {
  final String id;
  final String scribbleData; // JSON string from Scribble
  final String? screenshotPath;
  final String? name; // For standalone notes

  Note({
    required this.id,
    required this.scribbleData,
    this.screenshotPath,
    this.name,
  });

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
  Map<String, dynamic> toJson() => _$NoteToJson(this);

  Note copyWith({String? scribbleData, String? screenshotPath, String? name}) {
    return Note(
      id: id,
      scribbleData: scribbleData ?? this.scribbleData,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      name: name ?? this.name,
    );
  }
}
