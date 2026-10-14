import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReplySpeechService extends ChangeNotifier {
  final FlutterTts _tts;
  bool isSpeaking = false;
  bool _disposed = false;

  ReplySpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((_) => _setSpeaking(false));
  }

  void _setSpeaking(bool value) {
    if (_disposed || isSpeaking == value) return;
    isSpeaking = value;
    notifyListeners();
  }

  bool get supported =>
      kIsWeb ||
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;
  Future<void> speak(String text) async {
    if (!supported) {
      throw UnsupportedError('Speech output is not available on this platform');
    }
    await _tts.stop();
    final spoken = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), 'Code block. ')
        .replaceAll(RegExp(r'[*#`>]'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]*\)'),
          (match) => match.group(1)!,
        );
    final result = await _tts.speak(spoken);
    if (result == 0) {
      _setSpeaking(false);
      throw StateError('The device could not start speech playback');
    }
  }

  Future<void> stop() async {
    if (!supported) return;
    await _tts.stop();
    _setSpeaking(false);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
