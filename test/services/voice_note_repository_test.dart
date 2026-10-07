import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/voice_note.dart';
import 'package:exnote/services/voice/voice_note_repository.dart';

void main() {
  test(
    'unreadable voice metadata is reported without hiding other dictated notes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exnote_voice_recovery',
      );
      final repository = VoiceNoteRepository(directory: directory);
      addTearDown(() async {
        await repository.dispose();
        await directory.delete(recursive: true);
      });
      await repository.save('valid', [
        VoiceNote(
          id: 'voice',
          transcript: 'Valid text',
          createdAt: DateTime(2026),
        ),
      ]);
      final broken = await File(
        '${directory.path}/voice_notes/broken.json',
      ).writeAsString('invalid');
      final loaded = await repository.loadTexts();
      expect(loaded.texts['valid'], 'Valid text');
      expect(loaded.errors['broken'], isNotNull);
      expect(await broken.readAsString(), 'invalid');
    },
  );
  test(
    'voice text and audio references survive saving and notify search consumers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exnote_voice_test',
      );
      final repository = VoiceNoteRepository(directory: directory);
      addTearDown(() async {
        await repository.dispose();
        await directory.delete(recursive: true);
      });
      final changed = repository.changes.first;
      await repository.save('lecture', [
        VoiceNote(
          id: 'voice',
          audioPath: 'recordings/voice.m4a',
          transcript: 'Integration by parts',
          transcription: 'Recorded explanation',
          transcriptionCost: 0.0045,
          createdAt: DateTime(2026, 10, 7),
        ),
      ]);
      expect(await changed, 'lecture');
      final notes = await repository.load('lecture');
      expect(notes.single.audioPath, 'recordings/voice.m4a');
      expect(notes.single.transcription, 'Recorded explanation');
      expect(notes.single.transcriptionCost, 0.0045);
      expect(
        (await repository.loadTexts()).texts['lecture'],
        'Integration by parts\nRecorded explanation',
      );
      expect(await repository.load('empty'), isEmpty);
    },
  );
}
