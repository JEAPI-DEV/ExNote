import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/exercise_list.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';
import '../services/pdf_export_service.dart';
import '../services/pdf_processing_service.dart';
import 'pdf_viewer_screen.dart';
import 'page_selection_screen.dart';
import 'note_screen.dart';

class SubjectScreen extends ConsumerWidget {
  final String folderId;

  const SubjectScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref
        .watch(folderProvider)
        .firstWhere((f) => f.id == folderId);

    if (folder.isNoteFolder) {
      return _buildNoteFolderView(context, ref, folder);
    }

    return Scaffold(
      appBar: AppBar(title: Text(folder.name)),
      body: folder.exerciseLists.isEmpty
          ? const Center(child: Text('No exercise lists yet. Import a PDF!'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: folder.exerciseLists.length,
              itemBuilder: (context, index) {
                final list = folder.exerciseLists[index];
                return ListTile(
                  leading: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                  ),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => _exportPDF(context, ref, list),
                        tooltip: 'Export with Notes',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showRenameDialog(context, ref, folder, list),
                        tooltip: 'Rename',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _showDeleteDialog(context, ref, folder, list),
                      ),
                    ],
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

  Widget _buildNoteFolderView(BuildContext context, WidgetRef ref, folder) {
    final notes = folder.notes.values.toList();

    return Scaffold(
      appBar: AppBar(title: Text(folder.name)),
      body: notes.isEmpty
          ? const Center(child: Text('No notes yet. Create one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return ListTile(
                  leading: const Icon(Icons.note, color: Colors.blue),
                  title: Text(note.name ?? 'Untitled Note'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NoteScreen(folderId: folderId, noteId: note.id),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showRenameNoteDialog(context, ref, note),
                        tooltip: 'Rename',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _showDeleteNoteDialog(context, ref, note),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNoteDialog(context, ref),
        label: const Text('New Note'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter note name'),
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
                    .addStandaloneNote(folderId, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameNoteDialog(BuildContext context, WidgetRef ref, Note note) {
    final controller = TextEditingController(text: note.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new note name'),
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
                    .updateNoteName(folderId, note.id, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteNoteDialog(BuildContext context, WidgetRef ref, note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(folderProvider.notifier).deleteNote(folderId, note.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPDF(
    BuildContext context,
    WidgetRef ref,
    ExerciseList list,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF with notes...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exportService = PdfExportService();
      final outputFile = await exportService.exportExerciseListToPdf(list);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        await Share.shareXFiles([
          XFile(outputFile.path),
        ], text: 'Exported ${list.name}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importPDF(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      final name = result.files.single.name;

      if (!context.mounted) return;

      final selectionMode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Options'),
          content: const Text(
            'Do you want to import the entire PDF or select specific pages?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'all'),
              child: const Text('Import All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'select'),
              child: const Text('Select Pages'),
            ),
          ],
        ),
      );

      if (selectionMode == null) return;

      if (selectionMode == 'select') {
        if (!context.mounted) return;
        final selectedPages = await Navigator.push<List<int>>(
          context,
          MaterialPageRoute(
            builder: (_) => PageSelectionScreen(filePath: path),
          ),
        );

        if (selectedPages == null) return;

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        }

        try {
          final appDir = await getApplicationDocumentsDirectory();
          // Ensure directory exists
          final pdfDir = Directory('${appDir.path}/imported_pdfs');
          if (!await pdfDir.exists()) {
            await pdfDir.create(recursive: true);
          }

          final newPath =
              '${pdfDir.path}/${DateTime.now().millisecondsSinceEpoch}_filtered.pdf';

          await PdfProcessingService().extractPages(
            sourcePath: path,
            destinationPath: newPath,
            pageIndices: selectedPages,
          );

          path = newPath;
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to process PDF: $e')),
            );
          }
          return;
        }

        if (context.mounted) {
          Navigator.pop(context); // Close loading
        }
      }

      final nameController = TextEditingController(
        text: name.replaceAll('.pdf', ''),
      );

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
                  ref
                      .read(folderProvider.notifier)
                      .addExerciseList(folderId, nameController.text, path);
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

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    folder,
    ExerciseList list,
  ) {
    final controller = TextEditingController(text: list.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Exercise List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
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
                final updatedLists = folder.exerciseLists.map<ExerciseList>((
                  l,
                ) {
                  if (l.id == list.id) {
                    return l.copyWith(name: controller.text);
                  }
                  return l;
                }).toList();

                ref
                    .read(folderProvider.notifier)
                    .updateFolder(folder.copyWith(exerciseLists: updatedLists));
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
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
              final updatedLists = folder.exerciseLists
                  .where((l) => l.id != list.id)
                  .toList();
              ref
                  .read(folderProvider.notifier)
                  .updateFolder(folder.copyWith(exerciseLists: updatedLists));
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
