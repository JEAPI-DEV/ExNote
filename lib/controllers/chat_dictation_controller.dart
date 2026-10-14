import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Owns draft dictation, including callbacks after the chat drawer reopens.
class ChatDictationController extends ChangeNotifier {
  final TextEditingController text;
  final SpeechToText _speech;
  final Future<void> Function()? beforeListen;
  bool listening = false;
  bool starting = false;
  bool _disposed = false;
  bool _enabled = true;
  int _session = 0;
  String? error;

  ChatDictationController(this.text, {SpeechToText? speech, this.beforeListen})
    : _speech = speech ?? SpeechToText();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onStatus(String status) {
    if (_disposed) return;
    listening = status == SpeechToText.listeningStatus;
    _notify();
  }

  void _onError(SpeechRecognitionError failure) {
    if (_disposed) return;
    listening = false;
    error = switch (failure.errorMsg) {
      'error_permission' => 'Allow microphone access to dictate a message.',
      'error_no_match' || 'error_speech_timeout' =>
        'No speech detected. Tap the microphone and try again.',
      'error_network' || 'error_network_timeout' =>
        'Speech recognition needs a working network connection.',
      _ => 'Dictation failed: ${failure.errorMsg}',
    };
    _notify();
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled && (starting || listening)) stop(discardLateResults: true);
  }

  Future<void> toggle() async {
    if (_disposed || !_enabled || starting) return;
    if (listening) return stop();
    final session = ++_session;
    starting = true;
    error = null;
    _notify();
    try {
      await beforeListen?.call();
      if (_disposed || !_enabled || session != _session) return;
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (_disposed || !_enabled || session != _session) return;
      // initialize() is cached. Rebind callbacks to the current drawer even
      // when the plugin skips initialization after a previous drawer closed.
      _speech.statusListener = _onStatus;
      _speech.errorListener = _onError;
      if (!available) {
        throw StateError(
          'Speech recognition is unavailable. Check microphone permission and your device speech service.',
        );
      }
      final value = text.value;
      final selection = value.selection;
      final start = selection.isValid
          ? selection.start.clamp(0, value.text.length)
          : value.text.length;
      final end = selection.isValid
          ? selection.end.clamp(start, value.text.length)
          : value.text.length;
      final prefix = value.text.substring(0, start);
      final suffix = value.text.substring(end);
      listening = true;
      _notify();
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 5),
        ),
        onResult: (result) {
          if (_disposed || !_enabled || session != _session) return;
          final words = result.recognizedWords;
          if (words.isEmpty) return;
          final before = prefix.isNotEmpty && !RegExp(r'\s$').hasMatch(prefix)
              ? '$prefix '
              : prefix;
          final after = suffix.isNotEmpty && RegExp(r'^\w').hasMatch(suffix)
              ? ' $suffix'
              : suffix;
          text.value = TextEditingValue(
            text: '$before$words$after',
            selection: TextSelection.collapsed(
              offset: before.length + words.length,
            ),
          );
        },
      );
    } catch (failure) {
      if (!_disposed && session == _session) {
        listening = false;
        error = '$failure';
      }
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> stop({bool discardLateResults = false}) async {
    // A microphone stop still accepts the recognizer's final transcription.
    // Sending/closing a draft invalidates it so late results cannot rewrite it.
    if (discardLateResults || starting) ++_session;
    listening = false;
    _notify();
    try {
      await _speech.stop();
    } catch (failure) {
      error = 'Could not stop dictation: $failure';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_session;
    if (_speech.statusListener == _onStatus) {
      _speech.statusListener = null;
      _speech.errorListener = null;
      _speech.cancel().catchError((Object _) {});
    }
    super.dispose();
  }
}
