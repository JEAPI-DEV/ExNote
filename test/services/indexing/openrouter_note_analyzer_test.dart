import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:exnote/services/indexing/openrouter_note_analyzer.dart';
import 'package:exnote/services/notes/note_page_renderer.dart';

void main() {
  final page = NotePage(
    1,
    const Rect.fromLTWH(0, 0, 800, 1131),
    Uint8List.fromList([1, 2, 3]),
  );
  Map<String, dynamic> response({String finish = 'stop'}) => {
    'usage': {'cost': 0.001},
    'choices': [
      {
        'finish_reason': finish,
        'message': {
          'content': jsonEncode({
            'title': 'Induktion',
            'text': r'n^3 + 5n \equiv_6 0',
            'summary': 'Induktionsbeweis',
            'keywords': ['Induktion'],
          }),
        },
      },
    ],
  };
  test(
    'cloud scan uses chosen model, full page and structured transcription',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(request.url.path, '/api/v1/chat/completions');
        expect(body['model'], 'openai/gpt-6-luna');
        expect(body['response_format']['json_schema']['strict'], true);
        expect(
          body['messages'][0]['content'][1]['image_url']['detail'],
          'high',
        );
        expect(
          body['messages'][0]['content'][0]['text'],
          contains('student mistakes must remain visible'),
        );
        return http.Response(jsonEncode(response()), 200);
      });
      final analyzer = OpenRouterNoteAnalyzer(
        getApiKey: () async => 'test',
        client: client,
      );
      final result = await analyzer.analyze(page);
      expect(result.text, r'n^3 + 5n \equiv_6 0');
      expect(analyzer.spent, 0.001);
    },
  );
  test('no application spending limit blocks subsequent scans', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(response()), 200),
    );
    final analyzer = OpenRouterNoteAnalyzer(
      getApiKey: () async => 'test',
      client: client,
    )..spent = 1000;
    expect((await analyzer.analyze(page)).title, 'Induktion');
    expect(analyzer.spent, greaterThan(1000));
  });
  test('truncated output is not accepted as a completed annotation', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(response(finish: 'length')), 200),
    );
    await expectLater(
      OpenRouterNoteAnalyzer(
        getApiKey: () async => 'test',
        client: client,
      ).analyze(page),
      throwsFormatException,
    );
  });
  test(
    'missing token and provider errors stop the job rather than repeating paid requests',
    () async {
      await expectLater(
        OpenRouterNoteAnalyzer(getApiKey: () async => '').analyze(page),
        throwsA(isA<ScanStoppedException>()),
      );
      final client = MockClient((_) async => http.Response('quota', 402));
      await expectLater(
        OpenRouterNoteAnalyzer(
          getApiKey: () async => 'test',
          client: client,
        ).analyze(page),
        throwsA(isA<ScanStoppedException>()),
      );
    },
  );
}
