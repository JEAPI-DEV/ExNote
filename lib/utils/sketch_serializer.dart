import 'dart:convert';
import 'dart:isolate';
import 'package:scribble/scribble.dart';
import '../models/canvas_image.dart';

String _serializeSketch(Map<String, dynamic> data) {
  return jsonEncode(data);
}

Future<String> runSerialization(
  Sketch sketch, {
  List<CanvasImage> images = const [],
}) {
  final data = <String, dynamic>{
    'version': 2,
    'sketch': sketch.toJson(),
    'images': images.map((image) => image.toJson()).toList(),
  };
  return Isolate.run(() => _serializeSketch(data));
}

({Sketch sketch, List<CanvasImage> images}) deserializeNoteContent(
  String data,
) {
  final decoded = jsonDecode(data) as Map<String, dynamic>;

  if (decoded.containsKey('sketch') || decoded.containsKey('images')) {
    final sketchJson =
        (decoded['sketch'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{'lines': []};
    final imagesJson = decoded['images'] as List<dynamic>? ?? const [];
    return (
      sketch: Sketch.fromJson(sketchJson),
      images: imagesJson
          .map(
            (image) =>
                CanvasImage.fromJson((image as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  return (sketch: Sketch.fromJson(decoded), images: <CanvasImage>[]);
}
