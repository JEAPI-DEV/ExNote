import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';
import '../widgets/dialogs/app_dialogs.dart';
import '../widgets/dialogs/create_folder_dialog.dart';
import '../widgets/modals/folder_selection_tree.dart';
import '../screens/subject_screen.dart';

class FolderGrid extends ConsumerWidget {
  final List<Folder> folders;
  final bool isNoteTab;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const FolderGrid({
    super.key,
    required this.folders,
    required this.isNoteTab,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (folders.isEmpty) {
      return Center(
        child: Text(
          isNoteTab
              ? 'No note folders yet. Create one!'
              : 'No subjects yet. Create one!',
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final colorHex = folder.colorHex;
        final baseColor = colorHex != null
            ? Color(int.parse(colorHex, radix: 16)).withOpacity(1.0)
            : null;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = baseColor != null
            ? baseColor.withOpacity(isDark ? 0.2 : 0.1)
            : Theme.of(context).cardColor;
        final iconColor =
            baseColor ?? (Theme.of(context).iconTheme.color ?? Colors.blueGrey);

        return Card(
          color: bgColor,
          elevation: baseColor != null ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: baseColor != null && !isDark
                ? BorderSide(color: baseColor.withOpacity(0.3), width: 1)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectScreen(folderId: folder.id),
              ),
            ),
            onLongPress: () => _showFolderOptions(context, ref, folder),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNoteTab ? Icons.folder_shared : Icons.folder,
                  size: 48,
                  color: iconColor,
                ),
                const SizedBox(height: 8),
                Text(
                  folder.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  isNoteTab
                      ? '${folder.notes.length} notes'
                      : '${folder.exerciseLists.length} lists',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFolderOptions(BuildContext context, WidgetRef ref, Folder folder) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Folder Options',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(sheetContext);
                _renameFolder(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move),
              title: const Text('Move'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMoveFolderDialog(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteFolder(context, ref, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFolder(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final name = await AppDialogs.textInput(
      context: context,
      title: 'Rename Folder',
      hintText: 'Enter new folder name',
      initialText: folder.name,
      confirmText: 'Save',
    );
    if (name != null && context.mounted) {
      ref
          .read(folderProvider.notifier)
          .updateFolder(folder.copyWith(name: name));
    }
  }

  Future<void> _deleteFolder(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: 'Delete Folder',
      content:
          'Are you sure you want to delete "${folder.name}" and all its contents?',
      confirmText: 'Delete',
    );
    if (confirmed && context.mounted) {
      final deletedCount = await ref
          .read(folderProvider.notifier)
          .deleteFolder(folder.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted folder and $deletedCount items.')),
        );
      }
    }
  }

  void _showMoveFolderDialog(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final allFolders = ref.watch(folderProvider);
        return AlertDialog(
          title: const Text('Move Folder'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FolderSelectionTree(
              allFolders: allFolders,
              isNoteFolder: folder.isNoteFolder,
              currentParentId: folder.parentId,
              excludeFolderId: folder.id,
              onSelected: (targetFolderId) {
                if (targetFolderId != folder.parentId) {
                  ref
                      .read(folderProvider.notifier)
                      .moveFolder(folder.id, targetFolderId);
                  Navigator.pop(context);
                }
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
}
