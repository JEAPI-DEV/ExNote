import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/exercise_list.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';
import '../services/pdf_export_service.dart';
import '../services/pdf_processing_service.dart';
import '../widgets/dialogs/app_dialogs.dart';
import '../widgets/dialogs/create_folder_dialog.dart';
import '../widgets/folder_grid.dart';
import 'pdf_viewer_screen.dart';
import 'page_selection_screen.dart';

class ExerciseFolderScreen extends ConsumerWidget {
  final String folderId;
  final Folder folder;
  final List<Folder> subfolders;

  const ExerciseFolderScreen({
    super.key,
    required this.folderId,
    required this.folder,
    required this.subfolders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: () => _showAddSubfolderDialog(context, ref),
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
                              onPressed: () => _showRenameExerciseList(
                                context,
                                ref,
                                folder,
                                list,
                              ),
                              tooltip: 'Rename',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _showDeleteExerciseList(
                                context,
                                ref,
                                folder,
                                list,
                              ),
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

  void _showAddSubfolderDialog(BuildContext context, WidgetRef ref) {
    showCreateFolderDialog(
      context: context,
      ref: ref,
      title: 'New Subfolder',
      hintText: 'Enter folder name',
      isNoteFolder: false,
      parentId: folderId,
    );
  }

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
      final updatedLists = folder.exerciseLists
          .where((l) => l.id != list.id)
          .toList();
      ref
          .read(folderProvider.notifier)
          .updateFolder(folder.copyWith(exerciseLists: updatedLists));
    }
  }

  Future<void> _exportPDF(
    BuildContext context,
    WidgetRef ref,
    ExerciseList list,
  ) async {
    AppDialogs.showProgressDialog(
      context,
      message: 'Generating PDF with notes...',
    );

    try {
      final exportService = PdfExportService();
      final outputFile = await exportService.exportExerciseListToPdf(list);

      if (context.mounted) {
        AppDialogs.hideProgressDialog(context);
        await Share.shareXFiles([
          XFile(outputFile.path),
        ], text: 'Exported ${list.name}');
      }
    } catch (e) {
      if (context.mounted) {
        AppDialogs.hideProgressDialog(context);
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
        MaterialPageRoute(builder: (_) => PageSelectionScreen(filePath: path)),
      );

      if (selectedPages == null) return;

      if (context.mounted) {
        AppDialogs.showProgressDialog(context);
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
          AppDialogs.hideProgressDialog(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to process PDF: $e')));
        }
        return;
      }

      if (context.mounted) {
        AppDialogs.hideProgressDialog(context);
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
