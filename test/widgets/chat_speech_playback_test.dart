import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:exnote/controllers/ai_chat_controller.dart';
import 'package:exnote/models/chat_message.dart';
import 'package:exnote/services/ai/note_chat_context.dart';
import 'package:exnote/services/voice/reply_speech_service.dart';
import 'package:exnote/widgets/ai_chat_drawer.dart';

class FakeTts extends FlutterTts {
  VoidCallback? started;
  VoidCallback? completed;
  VoidCallback? cancelled;
  bool autoStart = true;
  bool fail = false;
  @override
  void setStartHandler(VoidCallback callback) => started = callback;
  @override
  void setCompletionHandler(VoidCallback callback) => completed = callback;
  @override
  void setCancelHandler(VoidCallback callback) => cancelled = callback;
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (fail) return 0;
    if (autoStart) started?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    cancelled?.call();
    return 1;
  }
}

class TestSpeech extends ReplySpeechService {
  TestSpeech(FakeTts tts) : super(tts: tts);
  @override
  bool get supported => true;
}

void main() {
  testWidgets(
    'only the playing reply swaps its speaker icon for stop and resets on completion',
    (tester) async {
      final tts = FakeTts()..autoStart = false;
      final speech = TestSpeech(tts);
      final chat = AiChatController()
        ..addMessage(ChatMessage(text: 'First reply', isAi: true))
        ..addMessage(ChatMessage(text: 'Second reply', isAi: true));
      addTearDown(chat.dispose);
      addTearDown(speech.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiChatDrawer(
              apiKey: '',
              model: 'openai/gpt-6-luna',
              isTutorMode: false,
              submitLastImageOnly: true,
              chatController: chat,
              speechService: speech,
              onClose: () {},
              onCaptureContext: () async => null,
              onNoteContext: (_) async => const NoteChatContext(),
              onWidthChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Read replies aloud'), findsNothing);
      expect(find.text('Stop reading'), findsNothing);
      expect(find.byTooltip('Stop reading'), findsNothing);
      await tester.tap(find.byTooltip('Read aloud').first);
      await tester.pump();
      expect(find.byTooltip('Stop reading'), findsNothing); // Not yet playing.
      tts.started!();
      await tester.pump();
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byTooltip('Read aloud'), findsOneWidget);
      chat.history[1] = ChatMessage(
        text: 'Streaming updated reply',
        isAi: true,
      );
      chat.setLoading(true);
      await tester.pump();
      expect(find.byTooltip('Stop reading'), findsOneWidget);
      chat.setLoading(false);
      await tester.pump();
      await tester.tap(find.byTooltip('Read aloud'));
      await tester.pump();
      tts.started!();
      await tester.pump();
      expect(find.byTooltip('Stop reading'), findsOneWidget);
      tts.completed!();
      await tester.pump();
      expect(find.byTooltip('Stop reading'), findsNothing);
      expect(find.byTooltip('Read aloud'), findsNWidgets(2));
      tts.autoStart = true;
      await tester.tap(find.byTooltip('Read aloud').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Stop reading'));
      await tester.pump();
      expect(find.byTooltip('Stop reading'), findsNothing);
      tts.fail = true;
      await tester.tap(find.byTooltip('Read aloud').first);
      await tester.pump();
      expect(find.byTooltip('Stop reading'), findsNothing);
      expect(find.textContaining('Speech playback failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
