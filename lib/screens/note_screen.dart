import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';
import '../providers/folder_provider.dart';
import '../widgets/scribble_toolbar.dart';

class NoteScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String exerciseListId;
  final String selectionId;
  final String noteId;

  const NoteScreen({
    super.key,
    required this.folderId,
    required this.exerciseListId,
    required this.selectionId,
    required this.noteId,
  });

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  late ScribbleNotifier notifier;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    notifier = ScribbleNotifier();
    notifier.setAllowedPointersMode(ScribblePointerMode.penOnly);

    // Update scale factor when zoom changes
    _transformationController.addListener(() {
      final scale = _transformationController.value.getMaxScaleOnAxis();
      notifier.setScaleFactor(scale);
    });

    // Load existing note if it exists
    _loadNote();
  }

  Future<void> _loadNote() async {
    final folder = ref
        .read(folderProvider)
        .firstWhere((f) => f.id == widget.folderId);
    final note = folder.notes[widget.noteId];

    if (note != null && note.scribbleData.isNotEmpty) {
      try {
        final sketchJson =
            jsonDecode(note.scribbleData) as Map<String, dynamic>;
        notifier.setSketch(sketch: Sketch.fromJson(sketchJson));
      } catch (e) {
        debugPrint('Error loading note: $e');
      }
    }
  }

  @override
  void dispose() {
    notifier.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folder = ref
        .watch(folderProvider)
        .firstWhere((f) => f.id == widget.folderId);
    final list = folder.exerciseLists.firstWhere(
      (l) => l.id == widget.exerciseListId,
    );
    final selection = list.selections.firstWhere(
      (s) => s.id == widget.selectionId,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Note'),
        actions: [
          ValueListenableBuilder(
            valueListenable: notifier,
            builder: (context, state, _) => IconButton(
              icon: const Icon(Icons.undo),
              onPressed: notifier.canUndo ? notifier.undo : null,
            ),
          ),
          ValueListenableBuilder(
            valueListenable: notifier,
            builder: (context, state, _) => IconButton(
              icon: const Icon(Icons.redo),
              onPressed: notifier.canRedo ? notifier.redo : null,
            ),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveNote),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.1, // Allow zooming out to 10%
            maxScale: 4.0,
            panEnabled: true,
            scaleEnabled: true,
            child: SizedBox.expand(
              child: Scribble(notifier: notifier, drawPen: true),
            ),
          ),
          // Screenshot in top left
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 350,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: selection.screenshotPath != null
                    ? Image.file(
                        File(selection.screenshotPath!),
                        fit: BoxFit.contain,
                      )
                    : const Center(
                        child: Text(
                          'No Screenshot',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
            ),
          ),
          // Toolbar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ScribbleToolbar(notifier: notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNote() async {
    try {
      final sketch = notifier.currentSketch;
      final jsonSketch = jsonEncode(sketch.toJson());

      final folder = ref
          .read(folderProvider)
          .firstWhere((f) => f.id == widget.folderId);
      final list = folder.exerciseLists.firstWhere(
        (l) => l.id == widget.exerciseListId,
      );
      final selection = list.selections.firstWhere(
        (s) => s.id == widget.selectionId,
      );

      await ref
          .read(folderProvider.notifier)
          .updateNote(
            widget.folderId,
            widget.noteId,
            jsonSketch,
            selection.screenshotPath,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
