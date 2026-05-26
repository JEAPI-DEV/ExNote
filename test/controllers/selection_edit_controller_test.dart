import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';

import 'package:exnote/controllers/selection_edit_controller.dart';
import 'package:exnote/models/undo_action.dart';

void main() {
  test('applies style to selected sketch lines', () {
    final line = SketchLine(
      points: const [Point(0, 0), Point(10, 10)],
      color: 0xFF000000,
      width: 2,
    );
    final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
    final selectionNotifier = ValueNotifier([line]);
    final actions = <UndoAction>[];
    final controller = SelectionEditController(
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      onAction: actions.add,
    );

    controller.applyStyle(color: Colors.red, strokeWidth: 8);

    final updated = sketchNotifier.value.lines.single;
    expect(updated.color, Colors.red.toARGB32());
    expect(updated.width, 8);
    expect(selectionNotifier.value.single, updated);
    expect(actions, hasLength(1));

    selectionNotifier.dispose();
    sketchNotifier.dispose();
  });

  test('mirrors selected sketch lines over axes', () {
    final line = SketchLine(
      points: const [Point(0, 0), Point(10, 10)],
      color: 0xFF000000,
      width: 2,
    );
    final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
    final selectionNotifier = ValueNotifier([line]);
    final controller = SelectionEditController(
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      onAction: (_) {},
    );

    controller.mirror(mirrorOverXAxis: true);

    var mirrored = sketchNotifier.value.lines.single.points;
    expect(mirrored[0].x, 0);
    expect(mirrored[0].y, 10);
    expect(mirrored[1].x, 10);
    expect(mirrored[1].y, 0);

    controller.mirror(mirrorOverXAxis: false);

    mirrored = sketchNotifier.value.lines.single.points;
    expect(mirrored[0].x, 10);
    expect(mirrored[0].y, 10);
    expect(mirrored[1].x, 0);
    expect(mirrored[1].y, 0);

    selectionNotifier.dispose();
    sketchNotifier.dispose();
  });
}
