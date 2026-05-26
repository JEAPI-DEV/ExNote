import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exnote/models/drawing_tool.dart';
import 'package:exnote/models/undo_action.dart';
import 'package:exnote/widgets/note_toolbar.dart';

Future<void> _pumpToolbar(
  WidgetTester tester, {
  required ValueNotifier<Sketch> sketchNotifier,
  required ValueNotifier<List<SketchLine>> selectionNotifier,
  required List<UndoAction> actions,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 1200,
            child: NoteToolbar(
              colorNotifier: ValueNotifier(Colors.black),
              widthNotifier: ValueNotifier(2),
              toolNotifier: ValueNotifier(DrawingTool.editSelection),
              sketchNotifier: sketchNotifier,
              selectionNotifier: selectionNotifier,
              onAction: actions.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mirrors selected lines over X axis', (tester) async {
    final line = SketchLine(
      points: const [Point(0, 0), Point(10, 10)],
      color: 0xFF000000,
      width: 2,
    );
    final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
    final selectionNotifier = ValueNotifier([line]);
    final actions = <UndoAction>[];

    await _pumpToolbar(
      tester,
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      actions: actions,
    );

    await tester.tap(find.byTooltip('Mirror over X axis'));
    await tester.pumpAndSettle();

    final mirrored = sketchNotifier.value.lines.single.points;
    expect(mirrored[0].x, 0);
    expect(mirrored[0].y, 10);
    expect(mirrored[1].x, 10);
    expect(mirrored[1].y, 0);
    expect(selectionNotifier.value.single.points, mirrored);
    expect(actions, hasLength(1));
  });

  testWidgets('mirrors selected lines over Y axis', (tester) async {
    final line = SketchLine(
      points: const [Point(0, 0), Point(10, 10)],
      color: 0xFF000000,
      width: 2,
    );
    final sketchNotifier = ValueNotifier(Sketch(lines: [line]));
    final selectionNotifier = ValueNotifier([line]);
    final actions = <UndoAction>[];

    await _pumpToolbar(
      tester,
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      actions: actions,
    );

    await tester.tap(find.byTooltip('Mirror over Y axis'));
    await tester.pumpAndSettle();

    final mirrored = sketchNotifier.value.lines.single.points;
    expect(mirrored[0].x, 10);
    expect(mirrored[0].y, 0);
    expect(mirrored[1].x, 0);
    expect(mirrored[1].y, 10);
    expect(selectionNotifier.value.single.points, mirrored);
    expect(actions, hasLength(1));
  });
}
