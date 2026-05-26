import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';

import 'package:exnote/controllers/drawing/resize_handler.dart';
import 'package:exnote/models/undo_action.dart';

void main() {
  group('ResizeHandler rotation', () {
    test('previews and commits selected line rotation', () {
      final line = SketchLine(
        points: const [Point(0, 0), Point(10, 0)],
        color: 0xFF000000,
        width: 2,
      );
      final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
      final selectionNotifier = ValueNotifier([line]);
      final actions = <UndoAction>[];
      var notifyCount = 0;
      var invalidateCount = 0;
      final handler = ResizeHandler(
        sketchNotifier: sketchNotifier,
        selectionNotifier: selectionNotifier,
        onAction: actions.add,
        notifyListeners: () => notifyCount++,
        invalidateCache: () => invalidateCount++,
      );
      const bounds = Rect.fromLTRB(0, 0, 10, 0);

      expect(
        handler.hitTestRotationHandle(const Offset(36, -26), bounds),
        true,
      );

      handler.startRotation(bounds, [line], const Offset(36, -26));
      handler.updateRotationPreview(const Offset(31, 31));

      final preview = handler.selectionForPainting.single.points;
      expect(preview[0].x, closeTo(5, 0.0001));
      expect(preview[0].y, closeTo(-5, 0.0001));
      expect(preview[1].x, closeTo(5, 0.0001));
      expect(preview[1].y, closeTo(5, 0.0001));

      handler.commitRotation();

      final committed = sketchNotifier.value.lines.single.points;
      expect(committed[0].x, closeTo(5, 0.0001));
      expect(committed[0].y, closeTo(-5, 0.0001));
      expect(committed[1].x, closeTo(5, 0.0001));
      expect(committed[1].y, closeTo(5, 0.0001));
      expect(selectionNotifier.value.single.points, committed);
      expect(actions, hasLength(1));
      expect(notifyCount, greaterThan(0));
      expect(invalidateCount, 1);

      selectionNotifier.dispose();
      sketchNotifier.dispose();
    });

    test('does not record an action for no-op rotation', () {
      final line = SketchLine(
        points: const [Point(0, 0), Point(10, 0)],
        color: 0xFF000000,
        width: 2,
      );
      final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
      final selectionNotifier = ValueNotifier([line]);
      final actions = <UndoAction>[];
      final handler = ResizeHandler(
        sketchNotifier: sketchNotifier,
        selectionNotifier: selectionNotifier,
        onAction: actions.add,
        notifyListeners: () {},
        invalidateCache: () {},
      );
      const bounds = Rect.fromLTRB(0, 0, 10, 0);

      handler.startRotation(bounds, [line], const Offset(36, -26));
      handler.updateRotationPreview(const Offset(36, -26));
      handler.commitRotation();

      expect(sketchNotifier.value.lines.single, line);
      expect(selectionNotifier.value.single, line);
      expect(actions, isEmpty);

      selectionNotifier.dispose();
      sketchNotifier.dispose();
    });

    test('keeps near-horizontal lines aligned while resizing', () {
      final line = SketchLine(
        points: const [Point(0, 0.2), Point(10, 0.4)],
        color: 0xFF000000,
        width: 2,
      );
      final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
      final selectionNotifier = ValueNotifier([line]);
      final handler = ResizeHandler(
        sketchNotifier: sketchNotifier,
        selectionNotifier: selectionNotifier,
        onAction: (_) {},
        notifyListeners: () {},
        invalidateCache: () {},
      );
      const bounds = Rect.fromLTRB(0, 0.2, 10, 0.4);

      handler.startResize(ResizeHandle.bottomRight, bounds, [line]);
      handler.updatePreview(const Offset(20, 20));

      final preview = handler.selectionForPainting.single.points;
      expect(preview[0].x, closeTo(0, 0.0001));
      expect(preview[1].x, closeTo(20, 0.0001));
      expect(preview[1].y - preview[0].y, closeTo(0.2, 0.0001));

      selectionNotifier.dispose();
      sketchNotifier.dispose();
    });
  });
}
