import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../models/exercise_list.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';
import '../services/backup/backup_merge_service.dart';

final storageServiceProvider = Provider((ref) {
  final storage = StorageService();
  ref.onDispose(storage.dispose);
  return storage;
});

final folderProvider = StateNotifierProvider<FolderNotifier, List<Folder>>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  return FolderNotifier(storage);
});

class FolderNotifier extends StateNotifier<List<Folder>> {
  final StorageService _storage;
  final _uuid = const Uuid();
  bool isLoading = true;
  String? loadError;

  FolderNotifier(this._storage) : super([]) {
    loadFolders();
  }

  Folder folderById(String id) => state.firstWhere((folder) => folder.id == id);

  Future<void> loadFolders() async {
    isLoading = true;
    loadError = null;
    try {
      final loaded = await _storage.loadFolders();
      if (!mounted) return;
      isLoading = false;
      state = loaded;
    } catch (error) {
      if (!mounted) return;
      isLoading = false;
      loadError = '$error';
      state = [...state];
    }
  }

  Future<String?> loadNoteData(String noteId) async {
    return await _storage.loadNote(noteId);
  }

  Future<void> addFolder(
    String name, {
    bool isNoteFolder = false,
    String? parentId,
    String? colorHex,
  }) async {
    final newFolder = Folder(
      id: _uuid.v4(),
      name: name,
      isNoteFolder: isNoteFolder,
      parentId: parentId,
      colorHex: colorHex,
    );
    state = [...state, newFolder];
    await _storage.saveFolders(state);
  }

  Future<int> deleteFolder(String id) async {
    // Delete target plus all its children recursively
    final Set<String> idsToDelete = {};
    void findChildren(String currentId) {
      idsToDelete.add(currentId);
      final children = state.where((f) => f.parentId == currentId);
      for (final child in children) {
        findChildren(child.id);
      }
    }

    findChildren(id);

    // Check how many items (notes, lists, etc) we are deleting
    int deletedFilesCount = 0;
    for (final folder in state.where((f) => idsToDelete.contains(f.id))) {
      deletedFilesCount += folder.notes.length;
      deletedFilesCount += folder.exerciseLists.length;
    }

    state = state.where((f) => !idsToDelete.contains(f.id)).toList();
    await _storage.saveFolders(state);

    return deletedFilesCount;
  }

  Future<void> moveFolder(String folderId, String? newParentId) async {
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(parentId: newParentId)
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> moveNote(
    String sourceFolderId,
    String targetFolderId,
    String noteId,
  ) async {
    if (sourceFolderId == targetFolderId) return;

    final sourceFolder = state.firstWhere((f) => f.id == sourceFolderId);
    final note = sourceFolder.notes[noteId];
    if (note == null) return;

    state = [
      for (final folder in state)
        if (folder.id == sourceFolderId)
          folder.copyWith(notes: Map.from(folder.notes)..remove(noteId))
        else if (folder.id == targetFolderId)
          folder.copyWith(notes: {...folder.notes, noteId: note})
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> moveExerciseList(
    String sourceFolderId,
    String targetFolderId,
    String listId,
  ) async {
    if (sourceFolderId == targetFolderId) return;

    final sourceFolder = state.firstWhere((f) => f.id == sourceFolderId);
    final list = sourceFolder.exerciseLists.firstWhere((l) => l.id == listId);

    state = [
      for (final folder in state)
        if (folder.id == sourceFolderId)
          folder.copyWith(
            exerciseLists: folder.exerciseLists
                .where((l) => l.id != listId)
                .toList(),
          )
        else if (folder.id == targetFolderId)
          folder.copyWith(exerciseLists: [...folder.exerciseLists, list])
        else
          folder,
    ];
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

  Future<void> addStandaloneNote(String folderId, String noteName) async {
    final noteId = _uuid.v4();
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(
            notes: {
              ...folder.notes,
              noteId: Note(
                id: noteId,
                name: noteName,
                scribbleData: "", // Ink yet to be saved
              ),
            },
          )
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> deleteNote(String folderId, String noteId) async {
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(notes: Map.from(folder.notes)..remove(noteId))
        else
          folder,
    ];
    await _storage.saveFolders(state);
    // Note: PDF selections still reference noteId, but we're mostly focused on general notes here.
  }

  Future<void> updateFolder(Folder updatedFolder) async {
    state = [
      for (final folder in state)
        if (folder.id == updatedFolder.id) updatedFolder else folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> updateExerciseList(
    String folderId,
    ExerciseList updatedList,
  ) async {
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(
            exerciseLists: [
              for (final list in folder.exerciseLists)
                if (list.id == updatedList.id) updatedList else list,
            ],
          )
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> updateNote(
    String folderId,
    String noteId,
    String scribbleData,
    String? screenshotPath,
  ) async {
    await _storage.saveNote(noteId, scribbleData);
    final existing = folderById(folderId).notes[noteId];
    if (existing != null &&
        existing.scribbleData.isEmpty &&
        (screenshotPath == null || screenshotPath == existing.screenshotPath)) {
      return; // Ink-only autosaves do not rewrite or rebuild the whole library.
    }

    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(
            notes: {
              ...folder.notes,
              noteId:
                  (folder.notes[noteId] ?? Note(id: noteId, scribbleData: ""))
                      .copyWith(
                        scribbleData: "", // Ink is saved separately
                        screenshotPath: screenshotPath,
                      ),
            },
          )
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> updateNoteName(
    String folderId,
    String noteId,
    String newName,
  ) async {
    state = [
      for (final folder in state)
        if (folder.id == folderId && folder.notes.containsKey(noteId))
          folder.copyWith(
            notes: {
              ...folder.notes,
              noteId: folder.notes[noteId]!.copyWith(name: newName),
            },
          )
        else
          folder,
    ];
    await _storage.saveFolders(state);
  }

  Future<void> mergeFromBackup(
    List<Folder> importedFolders,
    String sourceDirPath,
  ) async {
    final merged = await BackupMergeService(
      _storage,
    ).merge(state, importedFolders, sourceDirPath);
    await _storage.saveFolders(merged);
    state = merged;
  }
}
