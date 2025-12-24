import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../models/exercise_list.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final folderProvider = StateNotifierProvider<FolderNotifier, List<Folder>>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  return FolderNotifier(storage);
});

class FolderNotifier extends StateNotifier<List<Folder>> {
  final StorageService _storage;
  final _uuid = const Uuid();

  FolderNotifier(this._storage) : super([]) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    state = await _storage.loadFolders();
  }

  Future<void> addFolder(String name) async {
    final newFolder = Folder(id: _uuid.v4(), name: name);
    state = [...state, newFolder];
    await _storage.saveFolders(state);
  }

  Future<void> deleteFolder(String id) async {
    state = state.where((f) => f.id != id).toList();
    await _storage.saveFolders(state);
  }

  Future<void> addExerciseList(
    String folderId,
    String name,
    String pdfPath,
  ) async {
    final newList = ExerciseList(id: _uuid.v4(), name: name, pdfPath: pdfPath);
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(exerciseLists: [...folder.exerciseLists, newList])
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> updateFolder(Folder updatedFolder) async {
    state = [
      for (final folder in state)
        if (folder.id == updatedFolder.id) updatedFolder else folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> updateNote(
    String folderId,
    String noteId,
    String scribbleData,
    String? screenshotPath,
  ) async {
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(
            notes: {
              ...folder.notes,
              noteId: Note(
                id: noteId,
                scribbleData: scribbleData,
                screenshotPath: screenshotPath,
              ),
            },
          )
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }
}
