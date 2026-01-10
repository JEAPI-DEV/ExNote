import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/folder_provider.dart';
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Exercises', icon: Icon(Icons.assignment)),
              Tab(text: 'Notes', icon: Icon(Icons.note_alt)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FolderGrid(
              folders: folders.where((f) => !f.isNoteFolder).toList(),
              isNoteTab: false,
            ),
            _FolderGrid(
              folders: folders.where((f) => f.isNoteFolder).toList(),
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
}

class _FolderGrid extends ConsumerWidget {
  final List<dynamic> folders;
  final bool isNoteTab;

  const _FolderGrid({required this.folders, required this.isNoteTab});

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
            onLongPress: () => _showDeleteDialog(context, ref, folder),
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, dynamic folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "${folder.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(folderProvider.notifier).deleteFolder(folder.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
