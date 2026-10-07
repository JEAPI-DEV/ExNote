import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../models/voice_note.dart';

class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _id;
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required to record a note');
    }
    final root = await getApplicationDocumentsDirectory();
    await Directory('${root.path}/recordings').create(recursive: true);
    final id = const Uuid().v4();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: '${root.path}/recordings/$id.m4a',
    );
    _id = id;
  }

  Future<VoiceNote> stop({String transcript = ''}) async {
    final path = await _recorder.stop();
    if (path == null || _id == null) throw StateError('No recording was saved');
    return VoiceNote(
      id: _id!,
      audioPath: 'recordings/$_id.m4a',
      transcript: transcript,
      createdAt: DateTime.now(),
    );
  }

  Future<void> cancel() => _recorder.cancel();
  Future<void> dispose() => _recorder.dispose();
}
