import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:exnote/controllers/chat_dictation_controller.dart';

class FakeSpeech extends SpeechToText {
  FakeSpeech() : super.withMethodChannel();
  bool initialized = false;
  int listens = 0;
  Completer<bool>? initialization;
  SpeechResultListener? result;
  List<SpeechConfigOption>? config;
  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<SpeechConfigOption>? options,
  }) async {
    if (initialized) return true; // Reproduce the plugin's cached callbacks.
    statusListener = onStatus;
    errorListener = onError;
    config = options;
    initialized = initialization == null ? true : await initialization!.future;
    return initialized;
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listens++;
    result = onResult;
    statusListener?.call('listening');
  }

  void words(String text) => result?.call(
    SpeechRecognitionResult([SpeechRecognitionWords(text, null, 1)], 0),
  );
  @override
  Future<void> stop() async => statusListener?.call('notListening');
  @override
  Future<void> cancel() async {}
}

void main() {
  test(
    'reopened chat owns cached recognizer callbacks and remains stoppable',
    () async {
      final speech = FakeSpeech();
      final firstText = TextEditingController();
      final first = ChatDictationController(firstText, speech: speech);
      await first.toggle();
      expect(first.listening, true);
      first.dispose();
      firstText.dispose();
      final text = TextEditingController();
      final reopened = ChatDictationController(text, speech: speech);
      addTearDown(reopened.dispose);
      addTearDown(text.dispose);
      await reopened.toggle();
      expect(reopened.listening, true);
      speech.words('Explain this equation');
      expect(text.text, 'Explain this equation');
      speech.errorListener!(SpeechRecognitionError('error_network', true));
      expect(reopened.listening, false);
      expect(reopened.error, contains('network'));
      await reopened.toggle();
      await reopened.toggle();
      expect(reopened.listening, false);
      expect(speech.listens, 3);
      expect(speech.config, contains(SpeechToText.androidNoBluetooth));
    },
  );

  test(
    'partial results replace a selection without duplicating the draft',
    () async {
      final speech = FakeSpeech();
      final text = TextEditingController(text: 'Explain old please');
      text.selection = const TextSelection(baseOffset: 8, extentOffset: 11);
      final dictation = ChatDictationController(text, speech: speech);
      addTearDown(text.dispose);
      addTearDown(dictation.dispose);
      await dictation.toggle();
      speech.words('this');
      speech.words('this equation');
      expect(text.text, 'Explain this equation please');
      expect(text.selection.baseOffset, 'Explain this equation'.length);
      await dictation.stop();
      speech.words('this complete equation');
      expect(text.text, 'Explain this complete equation please');
      await dictation.stop(discardLateResults: true);
      text.clear(); // Sending clears the draft.
      speech.words('late final result');
      expect(text.text, isEmpty);
    },
  );

  test(
    'closing or sending during permission initialization never starts recording',
    () async {
      for (final close in [false, true]) {
        final speech = FakeSpeech()..initialization = Completer<bool>();
        final text = TextEditingController();
        final dictation = ChatDictationController(text, speech: speech);
        final starting = dictation.toggle();
        await Future<void>.delayed(Duration.zero);
        if (close) {
          dictation.dispose();
        } else {
          await dictation.stop();
        }
        speech.initialization!.complete(true);
        await starting;
        expect(speech.listens, 0);
        if (!close) dictation.dispose();
        text.dispose();
      }
    },
  );
}
