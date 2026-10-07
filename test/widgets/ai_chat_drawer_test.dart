import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/controllers/ai_chat_controller.dart';
import 'package:exnote/models/chat_message.dart';
import 'package:exnote/services/ai/note_chat_context.dart';
import 'package:exnote/widgets/ai_chat_drawer.dart';

void main() {
  testWidgets(
    'close control stays below system padding and preserves the conversation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.padding = const FakeViewPadding(top: 32);
      addTearDown(tester.view.resetPadding);
      final chat = AiChatController()
        ..addMessage(ChatMessage(text: 'Existing conversation', isAi: true));
      addTearDown(chat.dispose);
      bool closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiChatDrawer(
              apiKey: '',
              model: 'openai/gpt-6-luna',
              isTutorMode: false,
              submitLastImageOnly: true,
              chatController: chat,
              onClose: () => closed = true,
              onCaptureContext: () async => null,
              onNoteContext: (_) async => const NoteChatContext(),
              onWidthChanged: (_) {},
            ),
          ),
        ),
      );
      final close = find.byTooltip('Close assistant');
      expect(tester.getTopLeft(close).dy, greaterThanOrEqualTo(32));
      await tester.tap(close);
      expect(closed, true);
      expect(chat.history.single.text, 'Existing conversation');
    },
  );
}
