import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/exercise_list.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';
import '../services/pdf_export_service.dart';
import '../services/pdf_processing_service.dart';
import 'pdf_viewer_screen.dart';
import 'page_selection_screen.dart';
import 'note_screen.dart';
import 'folder_screen.dart';
import '../widgets/folder_color_picker.dart';
import '../widgets/note_card.dart';
import '../widgets/modals/folder_selection_tree.dart';
import '../widgets/dialogs/app_dialogs.dart';

class SubjectScreen extends ConsumerWidget {
  final String folderId;

  const SubjectScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFolders = ref.watch(folderProvider);
    final folder = allFolders.firstWhere((f) => f.id == folderId);
    final subfolders = allFolders.where((f) => f.parentId == folderId).toList();

    if (folder.isNoteFolder) {
      return _buildNoteFolderView(context, ref, folder, subfolders);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: () => _showAddSubfolderDialog(context, ref, false),
            tooltip: 'New Subfolder',
          ),
        ],
      ),
      body: folder.exerciseLists.isEmpty && subfolders.isEmpty
          ? const Center(child: Text('No lists or folders yet.'))
          : CustomScrollView(
              slivers: [
                if (subfolders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FolderGrid(
                      folders: subfolders,
                      isNoteTab: false,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                  ),
                if (folder.exerciseLists.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
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
                                  _showRenameExerciseList(context, ref, folder, list),
                              tooltip: 'Rename',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _showDeleteExerciseList(context, ref, folder, list),
                            ),
                          ],
                        ),
                      );
                    }, childCount: folder.exerciseLists.length),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importPDF(context, ref),
        label: const Text('Import PDF'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildNoteFolderView(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
    List<Folder> subfolders,
  ) {
    final notes = folder.notes.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: () => _showAddSubfolderDialog(context, ref, true),
            tooltip: 'New Subfolder',
          ),
        ],
      ),
      body: notes.isEmpty && subfolders.isEmpty
          ? const Center(child: Text('No notes or folders yet.'))
          : CustomScrollView(
              slivers: [
                if (subfolders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FolderGrid(
                      folders: subfolders,
                      isNoteTab: true,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                  ),
                if (notes.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final note = notes[index];
                        return NoteCard(
                          note: note,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NoteScreen(
                                folderId: folderId,
                                noteId: note.id,
                              ),
                            ),
                          ),
                          onRename: () => _renameNote(context, ref, note),
                          onMove: () => _showMoveNoteDialog(context, ref, note),
                          onDelete: () => _deleteNote(context, ref, note),
                        );
                      }, childCount: notes.length),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNote(context, ref),
        label: const Text('New Note'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // --- Note Actions ---

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final name = await AppDialogs.textInput(
      context: context,
      title: 'New Note',
      hintText: 'Enter note name',
    );
    if (name != null && context.mounted) {
      ref.read(folderProvider.notifier).addStandaloneNote(folderId, name);
    }
  }

  Future<void> _renameNote(BuildContext context, WidgetRef ref, Note note) async {
    final name = await AppDialogs.textInput(
      context: context,
      title: 'Rename Note',
      hintText: 'Enter new note name',
      initialText: note.name ?? '',
      confirmText: 'Rename',
    );
    if (name != null && context.mounted) {
      ref.read(folderProvider.notifier).updateNoteName(folderId, note.id, name);
    }
  }

  Future<void> _deleteNote(BuildContext context, WidgetRef ref, Note note) async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: 'Delete Note',
      content: 'Are you sure you want to delete "${note.name}"?',
      confirmText: 'Delete',
    );
    if (confirmed && context.mounted) {
      ref.read(folderProvider.notifier).deleteNote(folderId, note.id);
    }
  }

  // --- Exercise List Actions ---

  Future<void> _showRenameExerciseList(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
    ExerciseList list,
  ) async {
    final name = await AppDialogs.textInput(
      context: context,
      title: 'Rename Exercise List',
      hintText: 'Enter new name',
      initialText: list.name,
      confirmText: 'Rename',
    );
    if (name != null && context.mounted) {
      final updatedLists = folder.exerciseLists.map<ExerciseList>((l) {
        if (l.id == list.id) return l.copyWith(name: name);
        return l;
      }).toList();
      ref
          .read(folderProvider.notifier)
          .updateFolder(folder.copyWith(exerciseLists: updatedLists));
    }
  }

  Future<void> _showDeleteExerciseList(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
    ExerciseList list,
  ) async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: 'Delete List',
      content: 'Are you sure you want to delete "${list.name}"?',
      confirmText: 'Delete',
    );
    if (confirmed && context.mounted) {
      final updatedLists =
          folder.exerciseLists.where((l) => l.id != list.id).toList();
      ref
          .read(folderProvider.notifier)
          .updateFolder(folder.copyWith(exerciseLists: updatedLists));
    }
  }

  // --- Folder Actions ---

  void _showAddSubfolderDialog(
    BuildContext context,
    WidgetRef ref,
    bool isNoteFolder,
  ) {
    final controller = TextEditingController();
    String? selectedColorHex;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('New Subfolder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Enter folder name',
                  ),
                  autofocus: true,
                ),
                FolderColorPicker(
                  selectedColorHex: selectedColorHex,
                  onColorSelected: (hex) =>
                      setState(() => selectedColorHex = hex),
                ),
              ],
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
                        .addFolder(
                          controller.text,
                          isNoteFolder: isNoteFolder,
                          parentId: folderId,
                          colorHex: selectedColorHex,
                        );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMoveNoteDialog(BuildContext context, WidgetRef ref, Note note) {
    showDialog(
      context: context,
      builder: (context) {
        final allFolders = ref.watch(folderProvider);
        return AlertDialog(
          title: const Text('Move Note'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FolderSelectionTree(
              allFolders: allFolders,
              isNoteFolder: true,
              currentParentId: folderId,
              excludeFolderId: folderId,
              onSelected: (targetFolderId) {
                if (targetFolderId != null && targetFolderId != folderId) {
                  ref
                      .read(folderProvider.notifier)
                      .moveNote(folderId, targetFolderId, note.id);
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

  // --- PDF Import/Export ---

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
        Navigator.pop(context);
        await Share.shareXFiles([
          XFile(outputFile.path),
        ], text: 'Exported ${list.name}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
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

    if (result == null || result.files.single.path == null) return;

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
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process PDF: $e')),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.pop(context);
      }
    }

    if (!context.mounted) return;

    final listName = await AppDialogs.textInput(
      context: context,
      title: 'Name Exercise List',
      hintText: 'Enter name',
      initialText: name.replaceAll('.pdf', ''),
      confirmText: 'Import',
    );

    if (listName != null && context.mounted) {
      ref
          .read(folderProvider.notifier)
          .addExerciseList(folderId, listName, path);
    }
  }
}
