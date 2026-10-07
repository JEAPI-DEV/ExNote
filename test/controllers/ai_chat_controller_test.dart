import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/controllers/ai_chat_controller.dart';
import 'package:exnote/models/chat_message.dart';
import 'package:exnote/services/ai_service.dart';
import 'package:exnote/services/ai/note_chat_context.dart';

class FakeAiService extends AiService {
  final bool fail;
  int requests = 0;
  FakeAiService({this.fail = false}) : super(apiKey: 'test');
  @override
  Stream<String> streamMessage(
    List<ChatMessage> history, {
    bool submitLastImageOnly = true,
    NoteChatContext context = const NoteChatContext(),
  }) async* {
    requests++;
    if (fail) throw StateError('temporary failure');
    yield 'Answer ';
    yield 'ready';
  }
}

void main() {
  test('blocks duplicate sends while note context is prepared', () async {
    final chat = AiChatController();
    addTearDown(chat.dispose);
    final context = Completer<NoteChatContext>();
    final service = FakeAiService();
    chat.textController.text = 'Explain';
    final first = chat.send(service: service, context: (_) => context.future);
    chat.textController.text = 'Duplicate';
    await chat.send(service: service, context: (_) => context.future);
    expect(chat.history.where((item) => !item.isAi).length, 1);
    context.complete(const NoteChatContext());
    await first;
    expect(service.requests, 1);
    expect(chat.history.last.text, 'Answer ready');
    expect(chat.isLoading, false);
  });
  test('retry keeps the original user message and attachment once', () async {
    final chat = AiChatController();
    addTearDown(chat.dispose);
    chat.textController.text = 'Explain';
    chat.setPendingImage('crop');
    await chat.send(
      service: FakeAiService(fail: true),
      context: (_) async => const NoteChatContext(),
    );
    expect(chat.isLoading, false);
    expect(chat.error, contains('temporary failure'));
    await chat.send(
      service: FakeAiService(),
      context: (_) async => const NoteChatContext(),
      retry: true,
    );
    expect(chat.history.where((item) => !item.isAi).length, 1);
    expect(chat.history.first.base64Image, 'crop');
    expect(chat.history.last.text, 'Answer ready');
    expect(chat.error, null);
  });
  test(
    'closing the editor during context preparation suppresses late callbacks',
    () async {
      final chat = AiChatController();
      final context = Completer<NoteChatContext>();
      chat.textController.text = 'Explain';
      final send = chat.send(
        service: FakeAiService(),
        context: (_) => context.future,
      );
      chat.dispose();
      context.complete(const NoteChatContext());
      await send;
    },
  );
}
