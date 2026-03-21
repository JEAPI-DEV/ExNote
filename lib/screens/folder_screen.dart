import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/folder_provider.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import 'subject_screen.dart';

class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ExNote',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Exercises', icon: Icon(Icons.assignment)),
              Tab(text: 'Notes', icon: Icon(Icons.note_alt)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FolderGrid(
              folders: folders
                  .where((f) => !f.isNoteFolder && f.parentId == null)
                  .toList(),
              isNoteTab: false,
            ),
            FolderGrid(
              folders: folders
                  .where((f) => f.isNoteFolder && f.parentId == null)
                  .toList(),
              isNoteTab: true,
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () {
              final tabIndex = DefaultTabController.of(context).index;
              _showAddFolderDialog(context, ref, isNoteFolder: tabIndex == 1);
            },
            label: const Text('New Folder'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  void _showAddFolderDialog(
    BuildContext context,
    WidgetRef ref, {
    bool isNoteFolder = false,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNoteFolder ? 'New Note Folder' : 'New Subject'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isNoteFolder ? 'Enter folder name' : 'Enter subject name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(folderProvider.notifier)
                    .addFolder(controller.text, isNoteFolder: isNoteFolder);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Data Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.unarchive),
              title: const Text('Import Backup'),
              subtitle: const Text('Import notes from .zip file'),
              onTap: () {
                Navigator.pop(context);
                BackupService.importFromBackup(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Export All Data'),
              subtitle: const Text('Export all data to ZIP'),
              onTap: () async {
                Navigator.pop(context);
                // Implementation of export from main screen
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating backup...')),
                  );
                  // We can reuse ExportService.exportToZip() but it's currently
                  // static in NoteScreen context locally? No, it's a service.
                  final file = await ExportService.exportToZip();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Backup saved to ${file.path}')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class FolderGrid extends ConsumerWidget {
  final List<dynamic> folders;
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
        return Card(
          color: Theme.of(context).cardColor,
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
                  color: Theme.of(context).iconTheme.color ?? Colors.blueGrey,
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

  void _showFolderOptions(BuildContext context, WidgetRef ref, dynamic folder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
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
                Navigator.pop(context);
                _showRenameFolderDialog(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move),
              title: const Text('Move'),
              onTap: () {
                Navigator.pop(context);
                _showMoveFolderDialog(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, ref, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic folder,
  ) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(folderProvider.notifier)
                    .updateFolder(folder.copyWith(name: controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showMoveFolderDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic folder,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final allFolders = ref.read(folderProvider);
        // exclude self and children (to prevent cycles), but for simplicity just exclude self
        final validParents = allFolders
            .where(
              (f) => f.isNoteFolder == folder.isNoteFolder && f.id != folder.id,
            )
            .toList();

        return AlertDialog(
          title: const Text('Move Folder'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: validParents.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Root Structure'),
                    selected: folder.parentId == null,
                    onTap: () {
                      ref
                          .read(folderProvider.notifier)
                          .moveFolder(folder.id, null);
                      Navigator.pop(context);
                    },
                  );
                }
                final parent = validParents[index - 1];
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(parent.name),
                  selected: folder.parentId == parent.id,
                  onTap: () {
                    ref
                        .read(folderProvider.notifier)
                        .moveFolder(folder.id, parent.id);
                    Navigator.pop(context);
                  },
                );
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, dynamic folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}" and all its contents?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              int deletedCount = await ref
                  .read(folderProvider.notifier)
                  .deleteFolder(folder.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted folder and $deletedCount items.'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
