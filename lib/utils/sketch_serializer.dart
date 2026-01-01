import 'dart:convert';
import 'dart:isolate';
import 'package:scribble/scribble.dart';

String _serializeSketch(Sketch sketch) {
  return jsonEncode(sketch.toJson());
}

Future<String> runSerialization(Sketch sketch) {
  return Isolate.run(() => _serializeSketch(sketch));
}
