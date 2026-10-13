import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:scribble/scribble.dart';
import '../utils/sketch_serializer.dart';
import 'canvas_image.dart';
import 'canvas_object.dart';

/// A snapshot of the complete canvas, independent of zoom and scroll position.
class NoteDocument {
  final Sketch sketch;
  final List<CanvasImage> images;
  final List<CanvasObject> objects;

  const NoteDocument({
    required this.sketch,
    this.images = const [],
    this.objects = const [],
  });

  /// Compare authored content rather than viewport, thumbnails or JSON formatting.
  bool hasSameContent(NoteDocument other) =>
      sketch == other.sketch &&
      listEquals(
        images.map((image) => jsonEncode(image.toJson())).toList(),
        other.images.map((image) => jsonEncode(image.toJson())).toList(),
      ) &&
      listEquals(
        objects.map((object) => jsonEncode(object.toJson())).toList(),
        other.objects.map((object) => jsonEncode(object.toJson())).toList(),
      );

  factory NoteDocument.decode(String data) {
    if (data.isEmpty) return const NoteDocument(sketch: Sketch(lines: []));
    final content = deserializeNoteContent(data);
    return NoteDocument(
      sketch: content.sketch,
      images: content.images,
      objects: content.objects,
    );
  }
}
