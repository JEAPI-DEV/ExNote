import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exnote/models/drawing_tool.dart';
import 'package:exnote/models/note_settings.dart';
import 'package:exnote/models/undo_action.dart';
import 'package:exnote/widgets/edit_selection_controls.dart';
import 'package:exnote/widgets/note_toolbar.dart';

Future<void> _pumpToolbar(
  WidgetTester tester, {
  required NoteToolbarOrientation orientation,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: NoteToolbar(
            colorNotifier: ValueNotifier(Colors.black),
            widthNotifier: ValueNotifier(2),
            toolNotifier: ValueNotifier(DrawingTool.editSelection),
            sketchNotifier: ValueNotifier(Sketch(lines: const [])),
            selectionNotifier: ValueNotifier(<SketchLine>[]),
            onAction: (UndoAction _) {},
            orientation: orientation,
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

  testWidgets('vertical toolbar stays compact', (tester) async {
    await _pumpToolbar(tester, orientation: NoteToolbarOrientation.vertical);

    final size = tester.getSize(find.byType(NoteToolbar));
    expect(size.width, lessThan(100));
  });

  testWidgets('toolbox menu selects graph placement', (tester) async {
    final toolNotifier = ValueNotifier(DrawingTool.pen);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NoteToolbar(
              colorNotifier: ValueNotifier(Colors.black),
              widthNotifier: ValueNotifier(2),
              toolNotifier: toolNotifier,
              sketchNotifier: ValueNotifier(Sketch(lines: const [])),
              selectionNotifier: ValueNotifier(<SketchLine>[]),
              onAction: (UndoAction _) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Toolbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Graph Creator'));
    await tester.pumpAndSettle();

    expect(toolNotifier.value, DrawingTool.graphPlacement);
  });

  testWidgets('edit selection controls call mirror actions', (tester) async {
    var mirroredX = false;
    var mirroredY = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EditSelectionControls(
              editColor: Colors.black,
              editWidth: 2,
              onColorChanged: (_) {},
              onWidthChanged: (_) {},
              onWidthChangeEnd: () {},
              onMirrorX: () => mirroredX = true,
              onMirrorY: () => mirroredY = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Mirror over X axis'));
    await tester.tap(find.byTooltip('Mirror over Y axis'));

    expect(mirroredX, isTrue);
    expect(mirroredY, isTrue);
  });

  testWidgets('vertical edit selection controls stay compact', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EditSelectionControls(
              editColor: Colors.black,
              editWidth: 2,
              orientation: NoteToolbarOrientation.vertical,
              onColorChanged: (_) {},
              onWidthChanged: (_) {},
              onWidthChangeEnd: () {},
              onMirrorX: () {},
              onMirrorY: () {},
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(EditSelectionControls));
    expect(size.width, lessThan(100));
  });
}
