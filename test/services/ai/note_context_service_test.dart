import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:exnote/models/note_document.dart';
import 'package:exnote/models/voice_note.dart';
import 'package:exnote/models/indexing/note_index.dart';
import 'package:exnote/services/ai/note_context_service.dart';
import 'package:exnote/services/indexing/note_library_source.dart';
import 'package:exnote/services/notes/note_page_renderer.dart';
import 'package:exnote/services/storage_service.dart';
import 'package:exnote/services/voice/voice_note_repository.dart';

class FakePageRenderer extends NotePageRenderer {
  int calls = 0;
  @override
  Stream<NotePage> render(
    NoteDocument document, {
    String? backgroundPath,
  }) async* {
    calls++;
    for (int i = 1; i <= 8; i++) {
      yield NotePage(
        i,
        Rect.fromLTWH(0, i * 1000, 800, 1000),
        Uint8List.fromList([i]),
      );
    }
  }
}

void main() {
  late Directory directory;
  late StorageService storage;
  late VoiceNoteRepository voices;
  late NoteLibrarySource source;
  late FakePageRenderer renderer;
  late NoteContextService context;
  const current = LibraryNote(
    id: 'current',
    folderId: 'math',
    name: 'Current lecture',
    folderName: 'Math',
  );
  const other = LibraryNote(
    id: 'other',
    folderId: 'math',
    name: 'Integrals',
    folderName: 'Math',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exnote_context_test');
    storage = StorageService(directory: directory);
    voices = VoiceNoteRepository(directory: directory);
    source = NoteLibrarySource(storage);
    renderer = FakePageRenderer();
    context = NoteContextService(
      renderer: renderer,
      source: source,
      voiceNotes: voices,
    );
  });
  tearDown(() async {
    await storage.dispose();
    await voices.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'includes all eight current pages and reuses them for an unchanged canvas',
    () async {
      const document = NoteDocument(sketch: Sketch(lines: []));
      final first = await context.build(
        query: 'explain',
        current: current,
        document: document,
        library: [current],
      );
      expect(first.pageImages.length, 8);
      await voices.save(current.id, [
        VoiceNote(
          id: 'voice',
          transcript: 'Use substitution',
          createdAt: DateTime(2026),
        ),
      ]);
      final second = await context.build(
        query: 'explain',
        current: current,
        document: document,
        library: [current],
      );
      expect(renderer.calls, 1);
      expect(second.text, contains('Use substitution'));
    },
  );
  test('stale annotations are excluded from library references', () async {
    await storage.saveNote(other.id, '{"lines":[]}');
    final snapshot = await source.read(other);
    final entry = NoteIndex(
      noteId: other.id,
      fingerprint: snapshot.fingerprint,
      model: 'local',
      pageCount: 1,
      pages: const [
        IndexedPage(
          number: 1,
          title: 'Integrals',
          text: 'Old handwriting transcript',
          summary: '',
          keywords: [],
        ),
      ],
      complete: true,
    );
    await storage.saveNote(
      other.id,
      '{"version":3,"sketch":{"lines":[]},"images":[]}',
    );
    final result = await context.build(
      query: 'Integrals',
      current: current,
      document: const NoteDocument(sketch: Sketch(lines: [])),
      library: [current, other],
      indexes: {other.id: entry},
    );
    expect(result.text, isNot(contains('Old handwriting transcript')));
  });
  test(
    'dictated library text can be retrieved before handwriting is indexed',
    () async {
      await voices.save(other.id, [
        VoiceNote(
          id: 'voice',
          transcript: 'Integration by parts',
          createdAt: DateTime(2026),
        ),
      ]);
      final result = await context.build(
        query: 'integration',
        current: current,
        document: const NoteDocument(sketch: Sketch(lines: [])),
        library: [current, other],
        voiceTexts: {other.id: 'Integration by parts'},
      );
      expect(result.text, contains('Library reference: Integrals'));
      expect(result.text, contains('Integration by parts'));
    },
  );
}
