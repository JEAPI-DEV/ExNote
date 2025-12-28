import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/folder_provider.dart';
import '../widgets/fast_drawing_canvas.dart';
import '../widgets/fast_drawing_toolbar.dart';

enum GridType { grid, writingLines }

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
  late ValueNotifier<Sketch> sketchNotifier;
  late ValueNotifier<Color> colorNotifier;
  late ValueNotifier<double> widthNotifier;
  late ValueNotifier<DrawingTool> toolNotifier;
  final TransformationController _transformationController =
      TransformationController();

  bool gridEnabled = false;
  GridType gridType = GridType.grid;

  Timer? _autoSaveTimer;
  Size? _screenshotSize;
  final GlobalKey _exportKey = GlobalKey();

  // Undo/Redo History
  List<Sketch> _history = [];
  int _historyIndex = -1;
  bool _isUndoingRedoing = false;

  @override
  void initState() {
    super.initState();
    sketchNotifier = ValueNotifier(const Sketch(lines: []));
    colorNotifier = ValueNotifier(Colors.black);
    widthNotifier = ValueNotifier(2.0);
    toolNotifier = ValueNotifier(DrawingTool.pen);

    _loadSettings();
    _loadNote();

    sketchNotifier.addListener(_onSketchChanged);

    // Initialize history with empty sketch
    _history = [const Sketch(lines: [])];
    _historyIndex = 0;
  }

  void _onSketchChanged() {
    if (_isUndoingRedoing) return;

    // Remove any redo history if we are branching off
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }

    _history.add(sketchNotifier.value);
    _historyIndex = _history.length - 1;

    _scheduleAutoSave();
  }

  void _undo() {
    if (_historyIndex > 0) {
      _isUndoingRedoing = true;
      _historyIndex--;
      sketchNotifier.value = _history[_historyIndex];
      _isUndoingRedoing = false;
      _scheduleAutoSave();
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _isUndoingRedoing = true;
      _historyIndex++;
      sketchNotifier.value = _history[_historyIndex];
      _isUndoingRedoing = false;
      _scheduleAutoSave();
    }
  }

  void _clear() {
    sketchNotifier.value = const Sketch(lines: []);
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
        final loadedSketch = Sketch.fromJson(sketchJson);

        _isUndoingRedoing = true; // Prevent adding to history during load
        sketchNotifier.value = loadedSketch;
        _isUndoingRedoing = false;

        // Reset history to start with this loaded sketch
        _history = [loadedSketch];
        _historyIndex = 0;
      } catch (e) {
        debugPrint('Error loading note: $e');
      }
    }

    // Load screenshot if exists
    final list = folder.exerciseLists.firstWhere(
      (l) => l.id == widget.exerciseListId,
    );
    final selection = list.selections.firstWhere(
      (s) => s.id == widget.selectionId,
    );

    if (selection.screenshotPath != null) {
      // Get image dimensions
      final image = Image.file(File(selection.screenshotPath!));
      image.image
          .resolve(const ImageConfiguration())
          .addListener(
            ImageStreamListener((ImageInfo info, bool _) {
              if (mounted) {
                setState(() {
                  _screenshotSize = Size(
                    info.image.width.toDouble() / 2,
                    info.image.height.toDouble() / 2,
                  );
                });
              }
            }),
          );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveSettings();
    sketchNotifier.dispose();
    colorNotifier.dispose();
    widthNotifier.dispose();
    toolNotifier.dispose();
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exercise Note'),
          actions: [
            // Undo/Redo in AppBar
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: _undo,
            ),
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo),
              onPressed: _redo,
            ),
            IconButton(
              tooltip: 'Export PNG',
              icon: const Icon(Icons.image),
              onPressed: _exportPng,
            ),
            IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportPdf,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                _autoSaveTimer?.cancel();
                _saveNote();
              },
            ),
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
                title: const Text('Grid Enabled'),
                value: gridEnabled,
                onChanged: (bool value) {
                  setState(() {
                    gridEnabled = value;
                  });
                  _saveSettings();
                },
              ),
              if (gridEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButton<GridType>(
                    value: gridType,
                    onChanged: (GridType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          gridType = newValue;
                        });
                        _saveSettings();
                      }
                    },
                    items: GridType.values.map((GridType type) {
                      return DropdownMenuItem<GridType>(
                        value: type,
                        child: Text(
                          type == GridType.grid
                              ? 'Grid (Math)'
                              : 'Writing Lines',
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        body: Stack(
          children: [
            GestureDetector(
              onScaleStart: (details) {
                // Only allow scaling/panning if there are multiple pointers
                if (details.pointerCount < 2) {
                  // This will prevent the gesture from being recognized
                }
              },
              child: RepaintBoundary(
                key: _exportKey,
                child: InteractiveViewer(
                  constrained: false,
                  transformationController: _transformationController,
                  minScale: 0.01,
                  maxScale: 4.0,
                  panEnabled: false,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(50000.0),
                  child: SizedBox(
                    width: 100000.0,
                    height: 100000.0,
                    child: Stack(
                      children: [
                        if (gridEnabled)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: GridPainter(
                                matrix: _transformationController.value,
                                gridType: gridType,
                              ),
                            ),
                          ),
                        // Screenshot (relative to canvas)
                        Positioned(
                          top: 0,
                          left: 0,
                          child:
                              selection.screenshotPath != null &&
                                  _screenshotSize != null
                              ? Image.file(
                                  File(selection.screenshotPath!),
                                  width: _screenshotSize!.width,
                                  height: _screenshotSize!.height,
                                  fit: BoxFit.contain,
                                )
                              : selection.screenshotPath != null
                              ? Image.file(
                                  File(selection.screenshotPath!),
                                  width:
                                      400, // Half of original 800 as fallback
                                  fit: BoxFit.contain,
                                )
                              : const SizedBox.shrink(),
                        ),
                        // Custom Fast Drawing Layer
                        SizedBox.expand(
                          child: ValueListenableBuilder<Color>(
                            valueListenable: colorNotifier,
                            builder: (context, color, _) {
                              return ValueListenableBuilder<double>(
                                valueListenable: widthNotifier,
                                builder: (context, width, _) {
                                  return ValueListenableBuilder<DrawingTool>(
                                    valueListenable: toolNotifier,
                                    builder: (context, tool, _) {
                                      return FastDrawingCanvas(
                                        sketchNotifier: sketchNotifier,
                                        currentColor: color,
                                        currentWidth: width,
                                        currentTool: tool,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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
              child: FastDrawingToolbar(
                colorNotifier: colorNotifier,
                widthNotifier: widthNotifier,
                toolNotifier: toolNotifier,
                // onUndo/onRedo/onClear removed from toolbar as they are now in AppBar or handled differently
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    await _saveNote();
    return true;
  }

  Future<void> _saveNote() async {
    try {
      final sketch = sketchNotifier.value;
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

  Future<void> _exportPng() async {
    try {
      final boundary =
          _exportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to export')));
        return;
      }

      final dpi = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: dpi * 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final bytes = byteData.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/exnote_export_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported PNG to ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PNG export failed: $e')));
    }
  }

  Future<void> _exportPdf() async {
    try {
      final boundary =
          _exportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to export')));
        return;
      }

      final dpi = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: dpi * 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final bytes = byteData.buffer.asUint8List();

      final doc = pw.Document();
      final pwImage = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) =>
              pw.Center(child: pw.Image(pwImage, fit: pw.BoxFit.contain)),
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/exnote_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await doc.save());

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported PDF to ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        widthNotifier.value = prefs.getDouble('strokeWidth') ?? 2.0;
        gridEnabled = prefs.getBool('gridEnabled') ?? false;
        gridType = GridType.values[prefs.getInt('gridType') ?? 0];
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('strokeWidth', widthNotifier.value);
    await prefs.setBool('gridEnabled', gridEnabled);
    await prefs.setInt('gridType', gridType.index);
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNote();
    });
  }
}

class GridPainter extends CustomPainter {
  final Matrix4 matrix;
  final GridType gridType;

  GridPainter({required this.matrix, required this.gridType});

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

    if (gridType == GridType.grid) {
      // Draw grid (vertical and horizontal lines for math)
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
    } else {
      // Draw horizontal lines only (for writing)
      for (
        double y = (minY / spacing).floor() * spacing;
        y <= maxY;
        y += spacing
      ) {
        canvas.drawLine(Offset(minX, y), Offset(maxX, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      matrix != oldDelegate.matrix || gridType != oldDelegate.gridType;
}
