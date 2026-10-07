import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:exnote/models/indexing/indexing_settings.dart';
import 'package:exnote/services/indexing/openrouter_note_analyzer.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exnote/controllers/library_index_controller.dart';
import 'package:exnote/models/indexing/note_index.dart';
import 'package:exnote/models/indexing/indexed_region.dart';
import 'package:exnote/models/note_document.dart';
import 'package:exnote/services/indexing/local_note_analyzer.dart';
import 'package:exnote/services/indexing/note_index_repository.dart';
import 'package:exnote/services/indexing/note_library_source.dart';
import 'package:exnote/services/notes/note_page_renderer.dart';
import 'package:exnote/services/storage_service.dart';

class FakeRenderer extends NotePageRenderer {
  @override
  Stream<NotePage> render(
    NoteDocument document, {
    String? backgroundPath,
  }) async* {
    for (int i = 1; i <= 3; i++) {
      yield NotePage(i, const Rect.fromLTWH(0, 0, 800, 1131), Uint8List(0));
    }
  }
}

class FakeAnalyzer implements NoteAnalyzer {
  final List<int> calls = [];
  Future<void> Function(int)? onAnalyze;
  int closed = 0;
  int cancelled = 0;
  @override
  String get modelId => 'local-test';
  @override
  Future<IndexedPage> analyze(
    NotePage page, {
    List<IndexedRegion> previousRegions = const [],
    Future<void> Function(List<IndexedRegion>)? checkpoint,
  }) async {
    calls.add(page.number);
    await onAnalyze?.call(page.number);
    return IndexedPage(
      number: page.number,
      title: 'Page ${page.number}',
      text: 'Text',
      summary: '',
      keywords: [],
    );
  }

  @override
  Future<void> cancel() async {
    cancelled++;
  }

  @override
  Future<void> close() async {
    closed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;
  late FakeAnalyzer analyzer;
  late LibraryIndexController controller;
  const note = LibraryNote(
    id: 'a',
    folderId: 'folder',
    name: 'Lecture',
    folderName: 'Math',
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('exnote_index_test');
    storage = StorageService(directory: directory);
    await storage.saveNote('a', '{"lines":[]}');
    analyzer = FakeAnalyzer();
    controller = LibraryIndexController(
      repository: NoteIndexRepository(directory: directory),
      source: NoteLibrarySource(storage),
      analyzer: analyzer,
      renderer: FakeRenderer(),
    );
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await storage.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'paused scan checkpoints each page and resumes without duplicate inference',
    () async {
      analyzer.onAnalyze = (page) async {
        if (page == 1) controller.pause();
      };
      await controller.scan([note]);
      expect(controller.entries['a']!.complete, false);
      expect(controller.entries['a']!.pages.length, 1);
      analyzer.onAnalyze = null;
      await controller.scan([note]);
      expect(analyzer.calls, [1, 2, 3]);
      expect(controller.entries['a']!.complete, true);
      expect(controller.entries['a']!.pageCount, 3);
      await controller.scan([note]);
      expect(analyzer.calls, [1, 2, 3]);
      expect(analyzer.closed, 3);
    },
  );
  test(
    'changed source files invalidate checkpoints and are reanalyzed',
    () async {
      await controller.scan([note]);
      await storage.saveNote(
        'a',
        '{"version":3,"sketch":{"lines":[]},"images":[],"objects":[]}',
      );
      await controller.scan([note]);
      expect(analyzer.calls, [1, 2, 3, 1, 2, 3]);
    },
  );
  test(
    'a save during inference never produces a current completed index',
    () async {
      analyzer.onAnalyze = (page) async {
        if (page == 2) {
          await storage.saveNote(
            'a',
            '{"version":3,"sketch":{"lines":[]},"images":[]}',
          );
        }
      };
      await controller.scan([note]);
      expect(controller.entries['a']!.complete, false);
      expect(controller.failures['a'], contains('changed during analysis'));
    },
  );
  test(
    'saving unchanged content clears stale state without repeating inference',
    () async {
      await controller.scan([note]);
      controller.invalidate(note.id);
      await controller.scan([note]);
      expect(controller.staleNoteIds, isEmpty);
      expect(analyzer.calls, [1, 2, 3]);
    },
  );
  test('opening an editor interrupts active native inference', () async {
    analyzer.onAnalyze = (page) async {
      if (page == 1) controller.enterEditor();
    };
    await controller.scan([note]);
    expect(analyzer.cancelled, 1);
    expect(controller.failures, isEmpty);
    expect(controller.isRunning, false);
    expect(analyzer.closed, 1);
    controller.leaveEditor();
  });
  test('opening a note does not interrupt an active cloud scan', () async {
    controller.dispose();
    final key = Completer<String>();
    int requests = 0;
    final cloud = OpenRouterNoteAnalyzer(
      getApiKey: () => key.future,
      client: MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode({
            'usage': {'cost': 0.001},
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'content': jsonEncode({
                    'title': 'Lecture',
                    'text': 'Text',
                    'summary': '',
                    'keywords': [],
                  }),
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    controller = LibraryIndexController(
      repository: NoteIndexRepository(directory: directory),
      source: NoteLibrarySource(storage),
      analyzer: analyzer,
      cloudAnalyzer: cloud,
      renderer: FakeRenderer(),
    );
    await controller.initialize();
    await controller.configure(
      const IndexingSettings(backend: IndexingBackend.openRouter),
    );
    final scan = controller.scan([note]);
    await Future<void>.delayed(Duration.zero);
    controller.enterEditor();
    expect(controller.canScan, true);
    expect(controller.isPaused, false);
    key.complete('test');
    await scan;
    expect(requests, 3);
    expect(controller.entries[note.id]!.complete, true);
    controller.leaveEditor();
  });
  test('editing pauses analysis before any handwriting inference', () async {
    controller.enterEditor();
    await controller.scan([note]);
    expect(analyzer.calls, isEmpty);
    controller.leaveEditor();
    await controller.scan([note]);
    expect(analyzer.calls, [1, 2, 3]);
  });
}
