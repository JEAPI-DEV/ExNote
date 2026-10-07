import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:exnote/services/voice/audio_transcription_service.dart';

class CapturingClient extends http.BaseClient {
  final int status;
  final String response;
  Map<String, dynamic>? body;
  int? expectedLength;
  int? actualLength;
  Uri? url;
  CapturingClient(this.response, {this.status = 200});
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    url = request.url;
    expectedLength = request.contentLength;
    final bytes = await request.finalize().toBytes();
    actualLength = bytes.length;
    body = jsonDecode(utf8.decode(bytes));
    return http.StreamedResponse(Stream.value(utf8.encode(response)), status);
  }
}

void main() {
  test(
    'streams base64 audio with correct length and preserves model usage cost',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exnote_transcription_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/recording.m4a');
      final bytes = List.generate(150001, (i) => i % 256);
      await file.writeAsBytes(bytes);
      final client = CapturingClient(
        '{"text":" Spoken lecture ","usage":{"cost":0.0045}}',
      );
      final result = await AudioTranscriptionService(
        apiKey: 'test',
        client: client,
      ).transcribe(file);
      expect(client.url!.path, '/api/v1/audio/transcriptions');
      expect(client.body!['model'], 'openai/gpt-transcribe');
      expect(client.body!['input_audio']['format'], 'm4a');
      expect(base64Decode(client.body!['input_audio']['data']), bytes);
      expect(client.expectedLength, client.actualLength);
      expect(result.text, 'Spoken lecture');
      expect(result.cost, 0.0045);
    },
  );
  test('transcription failure preserves the original recording', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exnote_transcription_failure',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/recording.m4a',
    ).writeAsBytes([1, 2, 3]);
    await expectLater(
      AudioTranscriptionService(
        apiKey: 'test',
        client: CapturingClient('quota', status: 429),
      ).transcribe(file),
      throwsStateError,
    );
    expect(await file.readAsBytes(), [1, 2, 3]);
  });
}
