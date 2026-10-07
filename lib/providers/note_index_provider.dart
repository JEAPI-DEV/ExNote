import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/library_index_controller.dart';
import '../models/folder.dart';
import '../services/indexing/local_note_analyzer.dart';
import '../services/indexing/openrouter_note_analyzer.dart';
import '../services/settings_service.dart';
import '../services/indexing/note_index_repository.dart';
import '../services/indexing/note_library_source.dart';
import '../services/notes/note_page_renderer.dart';
import 'folder_provider.dart';
import 'voice_note_provider.dart';

final noteIndexProvider = ChangeNotifierProvider<LibraryIndexController>((ref) {
  final controller = LibraryIndexController(
    repository: NoteIndexRepository(),
    source: NoteLibrarySource(ref.read(storageServiceProvider)),
    analyzer: LocalNoteAnalyzer(),
    cloudAnalyzer: OpenRouterNoteAnalyzer(
      getApiKey: () async =>
          (await SettingsService.loadSettings()).openRouterToken,
    ),
    renderer: NotePageRenderer(),
    voiceNotes: ref.read(voiceNoteProvider),
  );
  ref.listen<List<Folder>>(
    folderProvider,
    (_, folders) => controller.setLibrary(LibraryNote.fromFolders(folders)),
    fireImmediately: true,
  );
  final changes = ref
      .read(storageServiceProvider)
      .changedNotes
      .listen(controller.invalidate);
  ref.onDispose(changes.cancel);
  final voices = ref
      .read(voiceNoteProvider)
      .changes
      .listen(controller.refreshVoice);
  ref.onDispose(voices.cancel);
  controller.initialize();
  return controller;
});
