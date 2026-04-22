import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/folder_grid.dart';
import '../widgets/dialogs/app_dialogs.dart';
import '../widgets/dialogs/create_folder_dialog.dart';
import '../widgets/dialogs/move_item_dialog.dart';
import 'note_screen.dart';

class NoteFolderScreen extends ConsumerWidget {
  final String folderId;
  final Folder folder;
  final List<Folder> subfolders;

  const NoteFolderScreen({
    super.key,
    required this.folderId,
    required this.folder,
    required this.subfolders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = folder.notes.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: () => showCreateFolderDialog(
              context: context,
              ref: ref,
              title: 'New Subfolder',
              hintText: 'Enter folder name',
              isNoteFolder: true,
              parentId: folderId,
            ),
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
                          onMove: () => _moveNote(context, ref, note),
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

  Future<void> _renameNote(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
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

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
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

  void _moveNote(BuildContext context, WidgetRef ref, Note note) {
    MoveItemDialog.show(
      context: context,
      ref: ref,
      isNoteFolder: true,
      excludeFolderId: folderId,
      currentParentId: folderId,
      onSelected: (targetFolderId) {
        if (targetFolderId != null && targetFolderId != folderId) {
          ref
              .read(folderProvider.notifier)
              .moveNote(folderId, targetFolderId, note.id);
        }
      },
    );
  }
}
