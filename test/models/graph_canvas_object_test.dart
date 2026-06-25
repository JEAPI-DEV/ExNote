import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/canvas_object.dart';
import 'package:exnote/models/graph_canvas_object.dart';

void main() {
  test(
    'graph canvas object round trips through generic canvas object JSON',
    () {
      const graph = GraphCanvasObject(
        id: 'graph-1',
        left: 10,
        top: 20,
        width: 300,
        height: 200,
        xAxisLabel: 'time',
        yAxisLabel: 'height',
        xMin: -5,
        xMax: 5,
        yMin: -2,
        yMax: 8,
        xTick: 1,
        yTick: 2,
        functions: [
          GraphFunctionSpec(
            id: 'fn-1',
            equation: 'f(x)=x^2',
            color: 0xFF0000FF,
          ),
        ],
      );

      final decoded = CanvasObject.fromJson(graph.toJson());

      expect(decoded, isA<GraphCanvasObject>());
      final decodedGraph = decoded as GraphCanvasObject;
      expect(decodedGraph.id, graph.id);
      expect(decodedGraph.bounds, graph.bounds);
      expect(decodedGraph.xAxisLabel, 'time');
      expect(decodedGraph.yAxisLabel, 'height');
      expect(decodedGraph.functions.single.equation, 'f(x)=x^2');
    },
  );

  test('graph visual resize preserves math settings', () {
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
      yMin: -4,
      yMax: 4,
      xTick: 2,
      yTick: 1,
      functions: [
        GraphFunctionSpec(id: 'fn-1', equation: 'g(t)=2t+1', color: 0xFFFF0000),
      ],
    );

    final resized = graph.copyWithBounds(
      left: 30,
      top: 40,
      width: 500,
      height: 260,
    );

    expect(resized.bounds.left, 30);
    expect(resized.bounds.width, 500);
    expect(resized.xMin, graph.xMin);
    expect(resized.xMax, graph.xMax);
    expect(resized.xTick, graph.xTick);
    expect(resized.functions.single.equation, graph.functions.single.equation);
  });
}
