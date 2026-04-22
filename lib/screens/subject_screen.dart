import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/folder_provider.dart';
import 'exercise_folder_screen.dart';
import 'note_folder_screen.dart';

class SubjectScreen extends ConsumerWidget {
  final String folderId;

  const SubjectScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFolders = ref.watch(folderProvider);
    final folder = allFolders.firstWhere((f) => f.id == folderId);
    final subfolders = allFolders.where((f) => f.parentId == folderId).toList();

    if (folder.isNoteFolder) {
      return NoteFolderScreen(
        folderId: folderId,
        folder: folder,
        subfolders: subfolders,
      );
    }

    return ExerciseFolderScreen(
      folderId: folderId,
      folder: folder,
      subfolders: subfolders,
    );
  }
}
