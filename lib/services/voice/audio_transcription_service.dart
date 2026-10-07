import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AudioTranscription {
  final String text;
  final double? cost;
  const AudioTranscription(this.text, this.cost);
}

/// Streams the audio upload so long recordings do not require a base64 copy in RAM.
class AudioTranscriptionService {
  final String apiKey;
  final http.Client? client;
  AudioTranscriptionService({required this.apiKey, this.client});

  Future<AudioTranscription> transcribe(File file) async {
    if (apiKey.trim().isEmpty) {
      throw StateError(
        'Set your OpenRouter token in Settings to transcribe recordings.',
      );
    }
    final transport = client ?? http.Client();
    try {
      final request = _AudioUpload(file, await file.length());
      request.headers.addAll({
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
        'X-Title': 'ExNote',
      });
      final response = await transport
          .send(request)
          .timeout(const Duration(seconds: 90));
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 90),
      );
      if (response.statusCode != 200) {
        throw StateError(
          'Transcription failed (${response.statusCode}). Your recording is still saved.',
        );
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final text = data['text'];
      if (text is! String || text.trim().isEmpty) {
        throw StateError(
          'No speech was transcribed. Your recording is still saved.',
        );
      }
      final cost = (data['usage'] as Map?)?['cost'];
      return AudioTranscription(
        text.trim(),
        cost is num ? cost.toDouble() : null,
      );
    } finally {
      if (client == null) transport.close();
    }
  }
}

class _AudioUpload extends http.BaseRequest {
  final File file;
  final List<int> prefix;
  static final suffix = utf8.encode('"},"response_format":"json"}');
  _AudioUpload(this.file, int length)
    : prefix = utf8.encode(
        '{"model":"openai/gpt-transcribe","input_audio":{"format":"m4a","data":"',
      ),
      super(
        'POST',
        Uri.parse('https://openrouter.ai/api/v1/audio/transcriptions'),
      ) {
    contentLength = prefix.length + ((length + 2) ~/ 3) * 4 + suffix.length;
  }
  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body());
  }

  Stream<List<int>> _body() async* {
    yield prefix;
    yield* file.openRead().transform(base64.encoder).map(utf8.encode);
    yield suffix;
  }
}
