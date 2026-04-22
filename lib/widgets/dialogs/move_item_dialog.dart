import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/folder.dart';
import '../../providers/folder_provider.dart';
import '../modals/folder_selection_tree.dart';

class MoveItemDialog extends StatelessWidget {
  final List<Folder> allFolders;
  final bool isNoteFolder;
  final String? currentParentId;
  final String excludeFolderId;
  final ValueChanged<String?> onSelected;

  const MoveItemDialog({
    super.key,
    required this.allFolders,
    required this.isNoteFolder,
    this.currentParentId,
    required this.excludeFolderId,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required bool isNoteFolder,
    required String excludeFolderId,
    required String? currentParentId,
    required ValueChanged<String?> onSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) {
        final allFolders = ref.watch(folderProvider);
        return AlertDialog(
          title: const Text('Move'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: MoveItemDialog(
              allFolders: allFolders,
              isNoteFolder: isNoteFolder,
              currentParentId: currentParentId,
              excludeFolderId: excludeFolderId,
              onSelected: (targetFolderId) {
                onSelected(targetFolderId);
                Navigator.pop(context);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FolderSelectionTree(
      allFolders: allFolders,
      isNoteFolder: isNoteFolder,
      currentParentId: currentParentId,
      excludeFolderId: excludeFolderId,
      onSelected: onSelected,
    );
  }
}
