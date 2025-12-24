import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/folder_provider.dart';
import 'subject_screen.dart';

class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: folders.isEmpty
          ? const Center(child: Text('No subjects yet. Create one!'))
          : GridView.builder(
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
                        const Icon(Icons.folder, size: 48, color: Colors.blueGrey),
                        const SizedBox(height: 8),
                        Text(
                          folder.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${folder.exerciseLists.length} lists',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFolderDialog(context, ref),
        label: const Text('New Subject'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Subject'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter subject name'),
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
                ref.read(folderProvider.notifier).addFolder(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
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
