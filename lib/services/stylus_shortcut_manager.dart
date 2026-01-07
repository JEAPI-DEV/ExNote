import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/drawing_tool.dart';

class StylusShortcutManager {
  StylusShortcutManager._() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static final StylusShortcutManager instance = StylusShortcutManager._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.excerciser/stylus',
  );

  ValueNotifier<DrawingTool>? _toolNotifier;

  void attach(ValueNotifier<DrawingTool> notifier) {
    _toolNotifier = notifier;
  }

  void detach(ValueNotifier<DrawingTool> notifier) {
    if (_toolNotifier == notifier) {
      _toolNotifier = null;
    }
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == 'stylusDoubleClick') {
      _toggleTool();
    }
  }

  void _toggleTool() {
    final notifier = _toolNotifier;
    if (notifier == null) {
      return;
    }
    final current = notifier.value;
    final next = current == DrawingTool.strokeEraser
        ? DrawingTool.pen
        : DrawingTool.strokeEraser;
    notifier.value = next;
  }
}
