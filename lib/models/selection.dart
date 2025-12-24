import 'package:json_annotation/json_annotation.dart';

part 'selection.g.dart';

@JsonSerializable()
class Selection {
  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final int pageIndex;
  final String noteId;
  final String? screenshotPath;

  Selection({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.pageIndex,
    required this.noteId,
    this.screenshotPath,
  });

  factory Selection.fromJson(Map<String, dynamic> json) => _$SelectionFromJson(json);
  Map<String, dynamic> toJson() => _$SelectionToJson(this);
}
