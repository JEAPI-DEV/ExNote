import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/folder_provider.dart';
import '../services/backup_service.dart';
import '../services/export/export_service.dart';
import '../widgets/dialogs/create_folder_dialog.dart';
import '../widgets/folder_grid.dart';

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
              onPressed: () => _showSettingsSheet(context, ref),
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
              showCreateFolderDialog(
                context: context,
                ref: ref,
                title: tabIndex == 1 ? 'New Note Folder' : 'New Subject',
                hintText: tabIndex == 1
                    ? 'Enter folder name'
                    : 'Enter subject name',
                isNoteFolder: tabIndex == 1,
              );
            },
            label: const Text('New Folder'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
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
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating backup...')),
                  );
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
