import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReplySpeechService {
  final FlutterTts _tts = FlutterTts();
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
    await _tts.speak(spoken);
  }

  Future<void> stop() async {
    if (!supported) return;
    await _tts.stop();
  }
}
