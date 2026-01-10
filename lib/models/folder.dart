import 'package:json_annotation/json_annotation.dart';
import 'exercise_list.dart';
import 'note.dart';

part 'folder.g.dart';

@JsonSerializable()
class Folder {
  final String id;
  final String name;
  final List<ExerciseList> exerciseLists;
  final Map<String, Note> notes;
  @JsonKey(defaultValue: false)
  final bool isNoteFolder;

  Folder({
    required this.id,
    required this.name,
    this.exerciseLists = const [],
    this.notes = const {},
    this.isNoteFolder = false,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => _$FolderFromJson(json);
  Map<String, dynamic> toJson() => _$FolderToJson(this);

  Folder copyWith({
    String? name,
    List<ExerciseList>? exerciseLists,
    Map<String, Note>? notes,
    bool? isNoteFolder,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      exerciseLists: exerciseLists ?? this.exerciseLists,
      notes: notes ?? this.notes,
      isNoteFolder: isNoteFolder ?? this.isNoteFolder,
    );
  }
}
