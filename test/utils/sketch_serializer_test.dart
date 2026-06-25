import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:exnote/models/graph_canvas_object.dart';
import 'package:exnote/utils/sketch_serializer.dart';

void main() {
  test('loads legacy raw sketch JSON without objects', () {
    final sketch = Sketch(lines: const []);

    final content = deserializeNoteContent(jsonEncode(sketch.toJson()));

    expect(content.sketch.lines, isEmpty);
    expect(content.images, isEmpty);
    expect(content.objects, isEmpty);
  });

  test('loads version 2 content without objects', () {
    final data = jsonEncode({
      'version': 2,
      'sketch': const Sketch(lines: []).toJson(),
      'images': [],
    });

    final content = deserializeNoteContent(data);

    expect(content.sketch.lines, isEmpty);
    expect(content.images, isEmpty);
    expect(content.objects, isEmpty);
  });

  test('serializes and loads version 3 content with graph objects', () async {
    const graph = GraphCanvasObject(
      id: 'graph-1',
      left: 10,
      top: 20,
      width: 300,
      height: 200,
      xAxisLabel: 'x',
      yAxisLabel: 'y',
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      xTick: 1,
      yTick: 1,
      functions: [
        GraphFunctionSpec(id: 'fn-1', equation: 'f(x)=x^2', color: 0xFF0000FF),
      ],
    );

    final data = await runSerialization(
      const Sketch(lines: []),
      objects: [graph],
    );
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    final content = deserializeNoteContent(data);

    expect(decoded['version'], 3);
    expect(content.objects.single, isA<GraphCanvasObject>());
    expect(
      (content.objects.single as GraphCanvasObject).functions.single.equation,
      'f(x)=x^2',
    );
  });
}
