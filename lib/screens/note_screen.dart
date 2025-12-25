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
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/folder_provider.dart';
import '../widgets/scribble_toolbar.dart';

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

class CustomScribbleNotifier extends ScribbleNotifier {
  /// Base distance threshold in logical pixels. This will be scaled by
  /// 1/scaleFactor so when zoomed in (scale>1) we record more points.
  final double baseThreshold;
  final double samplingExponent;

  // Lower baseThreshold for higher default density. Keep sketch optional.
  CustomScribbleNotifier({
    this.baseThreshold = 0.5,
    this.samplingExponent = 1.5,
    Sketch? sketch,
  }) : super(sketch: sketch);

  // Sampling scale is used only for deciding whether to insert new points
  // into the history queue. We keep it separate from the ScribbleNotifier's
  // internal scaleFactor so we don't affect rendering (which causes font
  // boldness to change when scaleFactor is adjusted).
  double _samplingScale = 1.0;

  double get samplingScale => _samplingScale;

  void setSamplingScale(double s) {
    _samplingScale = s;
  }

  @override
  bool shouldInsertValueIntoQueue(
    ScribbleState newValue,
    ScribbleState lastInQueue,
  ) {
    try {
      final newPos = newValue.pointerPosition;
      final lastPos = lastInQueue.pointerPosition;

      // If we don't have positions, fall back to inserting to keep things
      // consistent (e.g. pointer up/down events).
      if (newPos == null || lastPos == null) return true;

      // Use our separate sampling scale (keeps rendering unaffected).
      final scale = (_samplingScale <= 0) ? 1.0 : _samplingScale;
      // Use an exponent to make the threshold fall faster as zoom increases.
      final denom = math.pow(scale, samplingExponent);
      final threshold = (baseThreshold / (denom > 0 ? denom : 1.0)).clamp(
        0.05,
        20.0,
      );

      final dx = (newPos.x - lastPos.x);
      final dy = (newPos.y - lastPos.y);
      final dist = math.sqrt(dx * dx + dy * dy);
      return dist >= threshold;
    } catch (e) {
      // If anything unexpected, default to true to avoid losing input.
      return true;
    }
  }
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  late ScribbleNotifier notifier;
  final TransformationController _transformationController =
      TransformationController();

  double strokeWidth = 1.0;
  bool gridEnabled = false;
  GridType gridType = GridType.grid;

  Timer? _autoSaveTimer;
  Size? _screenshotSize;
  final GlobalKey _exportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    notifier = CustomScribbleNotifier();
    notifier.setAllowedPointersMode(ScribblePointerMode.penOnly);
    loadSettings();

    // Listen to notifier changes to sync strokeWidth and trigger autosave.
    // IMPORTANT: don't call setState here on every pointer update — that
    // causes a rebuild for each pen move and makes drawing feel sluggish.
    notifier.addListener(() {
      // keep a local copy in case other code needs it, but do NOT call
      // setState here. UI that needs realtime updates should use
      // ValueListenableBuilder on the notifier instead.
      strokeWidth = notifier.value.selectedWidth;
      _scheduleAutoSave();
    });

    // Keep the notifier aware of the current zoom so it can adapt the
    // sampling threshold (see CustomScribbleNotifier). Use a small delta to
    // avoid spamming setScaleFactor.
    _transformationController.addListener(() {
      final Matrix4 matrix = _transformationController.value;
      final double scale = matrix.getMaxScaleOnAxis();
      final double current = (notifier is CustomScribbleNotifier)
          ? (notifier as CustomScribbleNotifier).samplingScale
          : 1.0;
      if ((current - scale).abs() > 0.01) {
        if (notifier is CustomScribbleNotifier) {
          (notifier as CustomScribbleNotifier).setSamplingScale(scale);
        }
      }
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
              setState(() {
                _screenshotSize = Size(
                  info.image.width.toDouble() / 2,
                  info.image.height.toDouble() / 2,
                );
              });
            }),
          );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    saveSettings();
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exercise Note'),
          actions: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stroke Width'),
                    // Use ValueListenableBuilder so the slider updates from the
                    // notifier directly without a parent setState on every
                    // pointer move. This avoids expensive rebuilds.
                    ValueListenableBuilder(
                      valueListenable: notifier,
                      builder: (context, state, _) => Slider(
                        value: state.selectedWidth,
                        min: 1.0,
                        max: 20.0,
                        divisions: 19,
                        label: state.selectedWidth.round().toString(),
                        onChanged: (double value) =>
                            notifier.setStrokeWidth(value),
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('Grid Enabled'),
                value: gridEnabled,
                onChanged: (bool value) {
                  setState(() {
                    gridEnabled = value;
                  });
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
                        // Scribble layer
                        SizedBox.expand(
                          child: Scribble(notifier: notifier, drawPen: false),
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
              child: ScribbleToolbar(notifier: notifier),
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

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      strokeWidth = prefs.getDouble('strokeWidth') ?? 1.0;
      gridEnabled = prefs.getBool('gridEnabled') ?? false;
      gridType = GridType.values[prefs.getInt('gridType') ?? 0];
    });
    notifier.setStrokeWidth(strokeWidth);
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('strokeWidth', strokeWidth);
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
