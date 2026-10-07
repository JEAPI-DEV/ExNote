import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:exnote/services/ai_service.dart';
import 'package:exnote/services/ai/note_chat_context.dart';
import 'package:exnote/services/ai/ai_response_decoder.dart';
import 'package:exnote/models/chat_message.dart';

class StreamingClient extends http.BaseClient {
  final int status;
  final String body;
  StreamingClient(this.body, {this.status = 200});
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.fromIterable(utf8.encode(body).map((byte) => [byte])),
        status,
      );
}

void main() {
  test('full note pages survive the last extra screenshot filter', () {
    final service = AiService(apiKey: 'test');
    final request = service.request(
      [
        ChatMessage(text: 'old crop', isAi: false, base64Image: 'old'),
        ChatMessage(text: 'recent crop', isAi: false, base64Image: 'recent'),
      ],
      context: const NoteChatContext(
        text: 'Complete note',
        pageImages: ['page1', 'page2', 'page3'],
      ),
    );
    final encoded = jsonEncode(request);
    expect(request['model'], 'openai/gpt-6-luna');
    expect(encoded, contains('base64,page1'));
    expect(encoded, contains('base64,page2'));
    expect(encoded, contains('base64,page3'));
    expect(encoded, contains('base64,recent'));
    expect(encoded, isNot(contains('base64,old')));
    expect(request.containsKey('temperature'), false);
    expect(request['max_tokens'], 4096);
  });
  test(
    'decodes fragmented SSE with multibyte text and ignores keepalives',
    () async {
      final client = StreamingClient(
        ': heartbeat\n\ndata: {"choices":[{"delta":{"content":"für "}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"Mathematik"}}]}\n\ndata: [DONE]\n\n',
      );
      final result = await AiService(
        apiKey: 'test',
        client: client,
      ).sendMessage([]);
      expect(result, 'für Mathematik');
    },
  );
  test('HTTP failures are errors rather than assistant messages', () async {
    await expectLater(
      AiService(
        apiKey: 'test',
        client: StreamingClient('denied', status: 401),
      ).sendMessage([]),
      throwsStateError,
    );
  });
  test('SSE provider errors and truncated answers are surfaced', () {
    expect(
      () => decodeChatDelta('{"error":{"message":"quota"}}'),
      throwsStateError,
    );
    expect(
      () => decodeChatDelta(
        '{"choices":[{"finish_reason":"length","delta":{}}]}',
      ),
      throwsStateError,
    );
  });
}
