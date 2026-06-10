import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exnote/models/drawing_tool.dart';
import 'package:exnote/services/stylus_shortcut_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleTool switches between pen and stroke eraser', () {
    final manager = StylusShortcutManager.instance;
    final toolNotifier = ValueNotifier(DrawingTool.pen);
    manager.attach(toolNotifier);

    manager.toggleTool();
    expect(toolNotifier.value, DrawingTool.strokeEraser);

    manager.toggleTool();
    expect(toolNotifier.value, DrawingTool.pen);

    manager.detach(toolNotifier);
    toolNotifier.dispose();
  });
}
