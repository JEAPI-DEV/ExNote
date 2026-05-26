import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';

import 'package:exnote/controllers/drawing/pen_handler.dart';
import 'package:exnote/controllers/drawing/shape_snap_handler.dart';
import 'package:exnote/models/drawing_tool.dart';
import 'package:exnote/models/undo_action.dart';

List<Point> _generateEdgePoints(Point start, Point end, int count) {
  final points = <Point>[];
  for (int i = 0; i < count; i++) {
    final t = i / count;
    points.add(
      Point(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t),
    );
  }
  return points;
}

void main() {
  testWidgets('ignores further pen moves after a shape snaps', (tester) async {
    final squarePoints = [
      ..._generateEdgePoints(const Point(0, 0), const Point(100, 0), 10),
      ..._generateEdgePoints(const Point(100, 0), const Point(100, 100), 10),
      ..._generateEdgePoints(const Point(100, 100), const Point(0, 100), 10),
      ..._generateEdgePoints(const Point(0, 100), const Point(0, 0), 10),
      const Point(0, 0),
    ];
    final sketchNotifier = ValueNotifier(Sketch(lines: const []));
    final selectionNotifier = ValueNotifier(<SketchLine>[]);
    final currentLineNotifier = ValueNotifier<List<Point>?>(squarePoints);
    final actions = <UndoAction>[];
    final shapeSnapHandler = ShapeSnapHandler(
      currentLineNotifier: currentLineNotifier,
    );
    final penHandler = PenHandler(
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      currentLineNotifier: currentLineNotifier,
      onAction: actions.add,
      notifyListeners: () {},
      shapeSnapHandler: shapeSnapHandler,
    );

    shapeSnapHandler.startTimer();
    await tester.pump(const Duration(milliseconds: 700));

    expect(shapeSnapHandler.hasSnappedShape, isTrue);
    final snappedPoints = List<Point>.of(currentLineNotifier.value!);

    penHandler.handlePointerMove(
      const PointerMoveEvent(
        kind: PointerDeviceKind.stylus,
        position: Offset(250, 250),
        pressure: 1,
      ),
      scale: 1,
      shapeSnappingEnabled: true,
    );

    expect(currentLineNotifier.value, snappedPoints);

    penHandler.handlePointerUp(
      currentColor: Colors.black,
      currentWidth: 2,
      currentTool: DrawingTool.pen,
    );

    expect(sketchNotifier.value.lines.single.points, snappedPoints);
    expect(actions, hasLength(1));
    expect(shapeSnapHandler.hasSnappedShape, isFalse);

    shapeSnapHandler.dispose();
    currentLineNotifier.dispose();
    selectionNotifier.dispose();
    sketchNotifier.dispose();
  });
}
