import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/controllers/note_autosave_controller.dart';

void main() {
  testWidgets('waits for the pen to lift and coalesces changes', (
    tester,
  ) async {
    int saves = 0;
    final controller = NoteAutosaveController(
      save: () async {
        saves++;
      },
      onError: (_) {},
    );
    addTearDown(controller.dispose);
    controller.changed();
    controller.setDrawing(true);
    await tester.pump(const Duration(seconds: 5));
    expect(saves, 0);
    controller.setDrawing(false);
    controller.changed();
    controller.changed();
    await tester.pump(const Duration(seconds: 2));
    expect(saves, 1);
  });
  testWidgets('never runs two asynchronous saves concurrently', (tester) async {
    int saves = 0;
    final first = Completer<void>();
    final controller = NoteAutosaveController(
      save: () async {
        saves++;
        if (saves == 1) await first.future;
      },
      onError: (_) {},
    );
    addTearDown(controller.dispose);
    controller.changed();
    await tester.pump(const Duration(seconds: 2));
    expect(saves, 1);
    controller.changed();
    await tester.pump(const Duration(seconds: 2));
    expect(saves, 1);
    first.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(saves, 2);
  });
}
