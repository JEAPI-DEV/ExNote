import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
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

  bool _showGrid = false;

  @override
  void initState() {
    super.initState();
    notifier = ScribbleNotifier();
    notifier.setAllowedPointersMode(ScribblePointerMode.penOnly);

    // Update scale factor when zoom changes
    _transformationController.addListener(() {
      notifier.setScaleFactor(1.0);
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
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Settings',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            SwitchListTile(
              title: const Text('Grid Theme'),
              value: _showGrid,
              onChanged: (bool value) {
                setState(() {
                  _showGrid = value;
                });
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            transformationController: _transformationController,
            minScale: 0.01,
            maxScale: 4.0,
            panEnabled: true,
            scaleEnabled: true,
            boundaryMargin: const EdgeInsets.all(50000.0),
            child: SizedBox(
              width: 100000.0,
              height: 100000.0,
              child: Stack(
                children: [
                  if (_showGrid)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                          matrix: _transformationController.value,
                        ),
                      ),
                    ),
                  // Scribble layer
                  SizedBox.expand(
                    child: Scribble(notifier: notifier, drawPen: true),
                  ),
                  // Screenshot (relative to canvas)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: selection.screenshotPath != null
                        ? Image.file(
                            File(selection.screenshotPath!),
                            width: 800,
                            fit: BoxFit.contain,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
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

class GridPainter extends CustomPainter {
  final Matrix4 matrix;

  GridPainter({required this.matrix});

  @override
  void paint(Canvas canvas, Size size) {
    // Compute the inverse transformation
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return;

    // The visible rect in local coordinates is 0,0 to size.width, size.height
    // Transform to world coordinates
    final topLeft = inverse.transform3(vm.Vector3(0, 0, 0));
    final bottomRight = inverse.transform3(
      vm.Vector3(size.width, size.height, 0),
    );

    final minX = topLeft.x - 1000; // margin
    final maxX = bottomRight.x + 1000;
    final minY = topLeft.y - 1000;
    final maxY = bottomRight.y + 1000;

    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0;

    const double spacing = 20.0;

    // Draw vertical lines
    for (
      double x = (minX / spacing).floor() * spacing;
      x <= maxX;
      x += spacing
    ) {
      canvas.drawLine(Offset(x, minY), Offset(x, maxY), paint);
    }

    // Draw horizontal lines
    for (
      double y = (minY / spacing).floor() * spacing;
      y <= maxY;
      y += spacing
    ) {
      canvas.drawLine(Offset(minX, y), Offset(maxX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      matrix != oldDelegate.matrix;
}
