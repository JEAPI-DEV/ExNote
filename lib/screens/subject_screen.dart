import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/folder_provider.dart';
import 'pdf_viewer_screen.dart';

class SubjectScreen extends ConsumerWidget {
  final String folderId;

  const SubjectScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(folderProvider).firstWhere((f) => f.id == folderId);

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
      ),
      body: folder.exerciseLists.isEmpty
          ? const Center(child: Text('No exercise lists yet. Import a PDF!'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: folder.exerciseLists.length,
              itemBuilder: (context, index) {
                final list = folder.exerciseLists[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(list.name),
                  subtitle: Text('${list.selections.length} exercises'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PDFViewerScreen(
                        folderId: folderId,
                        exerciseListId: list.id,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showDeleteDialog(context, ref, folder, list),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importPDF(context, ref),
        label: const Text('Import PDF'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _importPDF(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;

      final nameController = TextEditingController(text: name.replaceAll('.pdf', ''));
      
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Name Exercise List'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref.read(folderProvider.notifier).addExerciseList(
                        folderId,
                        nameController.text,
                        path,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, folder, list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updatedLists = folder.exerciseLists.where((l) => l.id != list.id).toList();
              ref.read(folderProvider.notifier).updateFolder(
                    folder.copyWith(exerciseLists: updatedLists),
                  );
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
