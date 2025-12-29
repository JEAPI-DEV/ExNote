import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
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
import '../models/drawing_tool.dart';
import '../widgets/note_app_bar.dart';
import '../widgets/note_toolbar.dart';
import '../widgets/ai_chat_drawer.dart';

enum GridType { grid, writingLines }

enum RightDrawerContent { settings, aiChat }

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
  late ValueNotifier<List<SketchLine>> selectionNotifier;
  late ValueNotifier<Color> colorNotifier;
  late ValueNotifier<double> widthNotifier;
  late ValueNotifier<DrawingTool> toolNotifier;
  final TransformationController _transformationController =
      TransformationController();

  // GlobalKey to fix Scaffold.of context issue
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool gridEnabled = false;
  GridType gridType = GridType.grid;
  RightDrawerContent _rightDrawerContent = RightDrawerContent.settings;

  Timer? _autoSaveTimer;
  Size? _screenshotSize;
  final GlobalKey _exportKey = GlobalKey();

  // AI Settings
  String openRouterToken = '';
  bool tutorEnabled = false;
  final TextEditingController _tokenController = TextEditingController();

  // Undo/Redo History
  List<Sketch> _history = [];
  int _historyIndex = -1;
  bool _isUndoingRedoing = false;
  bool _isLoading = true;

  // Clipboard
  List<SketchLine> _clipboard = [];

  @override
  void initState() {
    super.initState();
    sketchNotifier = ValueNotifier(const Sketch(lines: []));
    selectionNotifier = ValueNotifier([]);
    colorNotifier = ValueNotifier(Colors.black);
    widthNotifier = ValueNotifier(2.0);
    toolNotifier = ValueNotifier(DrawingTool.pen);

    _loadSettings();
    _loadNote();

    sketchNotifier.addListener(_onSketchChanged);
    selectionNotifier.addListener(() {
      if (mounted) setState(() {});
    });

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
    setState(() {}); // Update UI immediately
    _scheduleAutoSave();
  }

  void _undo() {
    if (_historyIndex > 0) {
      _isUndoingRedoing = true;
      _historyIndex--;
      sketchNotifier.value = _history[_historyIndex];
      _isUndoingRedoing = false;
      setState(() {}); // Update UI immediately
      _scheduleAutoSave();
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _isUndoingRedoing = true;
      _historyIndex++;
      sketchNotifier.value = _history[_historyIndex];
      _isUndoingRedoing = false;
      setState(() {}); // Update UI immediately
      _scheduleAutoSave();
    }
  }

  void _deleteSelection() {
    final selectedLines = selectionNotifier.value;
    if (selectedLines.isEmpty) return;

    final currentSketch = sketchNotifier.value;
    final remainingLines = currentSketch.lines
        .where((line) => !selectedLines.contains(line))
        .toList();

    sketchNotifier.value = Sketch(lines: remainingLines);
    selectionNotifier.value = [];
  }

  void _copy() {
    final selected = selectionNotifier.value;
    if (selected.isEmpty) return;

    // Deep copy
    _clipboard = selected
        .map(
          (line) => line.copyWith(
            points: line.points
                .map((p) => Point(p.x, p.y, pressure: p.pressure))
                .toList(),
          ),
        )
        .toList();

    setState(() {}); // Update UI to enable Paste button
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _paste() {
    if (_clipboard.isEmpty) return;

    final currentSketch = sketchNotifier.value;

    // Paste with offset
    final offset = 20.0;
    final pastedLines = _clipboard.map((line) {
      final newPoints = line.points
          .map((p) => Point(p.x + offset, p.y + offset, pressure: p.pressure))
          .toList();
      return line.copyWith(points: newPoints);
    }).toList();

    // Update clipboard to have the offset for next paste
    _clipboard = pastedLines;

    sketchNotifier.value = Sketch(
      lines: [...currentSketch.lines, ...pastedLines],
    );

    // Select pasted lines
    selectionNotifier.value = pastedLines;
    toolNotifier.value = DrawingTool.selection;
  }

  Future<void> _loadNote() async {
    try {
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
    } catch (e) {
      debugPrint('Error loading note: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveSettings();
    sketchNotifier.dispose();
    selectionNotifier.dispose();
    colorNotifier.dispose();
    widthNotifier.dispose();
    toolNotifier.dispose();
    _transformationController.dispose();
    _tokenController.dispose();
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

    final themeMode = ref.watch(themeProvider);

    return Builder(
      builder: (context) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (didPop) {
              await _saveNote();
            }
          },
          child: Scaffold(
            key: _scaffoldKey, // Assign GlobalKey
            extendBodyBehindAppBar: true,
            appBar: NoteAppBar(
              onUndo: _undo,
              onRedo: _redo,
              onCopy: _copy,
              onPaste: _paste,
              onExportPng: _exportPng,
              onExportPdf: _exportPdf,
              onSave: () {
                _autoSaveTimer?.cancel();
                _saveNote();
              },
              onSettings: () {
                setState(
                  () => _rightDrawerContent = RightDrawerContent.settings,
                );
                _scaffoldKey.currentState?.openEndDrawer();
              },
              onBack: () async {
                await _saveNote();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              onDelete: selectionNotifier.value.isNotEmpty
                  ? _deleteSelection
                  : null,
              onChat: () {
                setState(() => _rightDrawerContent = RightDrawerContent.aiChat);
                _scaffoldKey.currentState?.openEndDrawer();
              },
              canUndo: _historyIndex > 0,
              canRedo: _historyIndex < _history.length - 1,
              canCopy: selectionNotifier.value.isNotEmpty,
              canPaste: _clipboard.isNotEmpty,
            ),
            endDrawer: _rightDrawerContent == RightDrawerContent.aiChat
                ? AiChatDrawer(
                    apiKey: openRouterToken,
                    isTutorMode: tutorEnabled,
                    onCaptureContext: _captureCanvas,
                  )
                : Drawer(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 24,
                            ),
                          ),
                        ),

                        // Theme Selection
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theme',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text('System'),
                                    icon: Icon(Icons.brightness_auto),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text('Light'),
                                    icon: Icon(Icons.light_mode),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text('Dark'),
                                    icon: Icon(Icons.dark_mode),
                                  ),
                                ],
                                selected: {themeMode},
                                onSelectionChanged:
                                    (Set<ThemeMode> newSelection) {
                                      ref
                                          .read(themeProvider.notifier)
                                          .setThemeMode(newSelection.first);
                                    },
                              ),
                            ],
                          ),
                        ),
                        const Divider(),

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
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
                        const Divider(),

                        // AI Settings
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Settings',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _tokenController,
                                decoration: const InputDecoration(
                                  labelText: 'OpenRouter API Token',
                                  border: OutlineInputBorder(),
                                  hintText: 'sk-or-v1-...',
                                ),
                                obscureText: true,
                                onChanged: (value) {
                                  openRouterToken = value;
                                  _saveSettings();
                                },
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Tutor Mode'),
                                subtitle: const Text(
                                  'AI will act as a helpful tutor',
                                ),
                                value: tutorEnabled,
                                onChanged: (bool value) {
                                  setState(() {
                                    tutorEnabled = value;
                                  });
                                  _saveSettings();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            body: Stack(
              children: [
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  GestureDetector(
                    onScaleStart: (details) {
                      if (details.pointerCount < 2) {
                        // Prevent single finger gesture
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
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
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
                                          width: 400,
                                          fit: BoxFit.contain,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                SizedBox.expand(
                                  child: ValueListenableBuilder<Color>(
                                    valueListenable: colorNotifier,
                                    builder: (context, color, _) {
                                      return ValueListenableBuilder<double>(
                                        valueListenable: widthNotifier,
                                        builder: (context, width, _) {
                                          return ValueListenableBuilder<
                                            DrawingTool
                                          >(
                                            valueListenable: toolNotifier,
                                            builder: (context, tool, _) {
                                              return FastDrawingCanvas(
                                                sketchNotifier: sketchNotifier,
                                                selectionNotifier:
                                                    selectionNotifier,
                                                currentColor: color,
                                                currentWidth: width,
                                                currentTool: tool,
                                                scale: _transformationController
                                                    .value
                                                    .getMaxScaleOnAxis(),
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
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: NoteToolbar(
                    colorNotifier: colorNotifier,
                    widthNotifier: widthNotifier,
                    toolNotifier: toolNotifier,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveNote() async {
    try {
      final sketch = sketchNotifier.value;
      final jsonSketch = await _runSerialization(sketch);

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

      final dir = await _getExportDirectory();
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

      final dir = await _getExportDirectory();
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

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Standard public Download folder
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }

      // Fallback to Documents if Download doesn't exist
      final documentsDir = Directory('/storage/emulated/0/Documents');
      if (await documentsDir.exists()) {
        return documentsDir;
      }

      // Fallback to app-specific external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }

    // On iOS or as final fallback, use application documents directory
    // (Visible in Files app due to Info.plist changes)
    return await getApplicationDocumentsDirectory();
  }

  Future<String?> _captureCanvas() async {
    try {
      final boundary =
          _exportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      return base64Encode(pngBytes);
    } catch (e) {
      debugPrint('Error capturing canvas: $e');
      return null;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        widthNotifier.value = prefs.getDouble('strokeWidth') ?? 2.0;
        gridEnabled = prefs.getBool('gridEnabled') ?? false;
        gridType = GridType.values[prefs.getInt('gridType') ?? 0];
        openRouterToken = prefs.getString('openRouterToken') ?? '';
        _tokenController.text = openRouterToken;
        tutorEnabled = prefs.getBool('tutorEnabled') ?? false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('strokeWidth', widthNotifier.value);
    await prefs.setBool('gridEnabled', gridEnabled);
    await prefs.setInt('gridType', gridType.index);
    await prefs.setString('openRouterToken', openRouterToken);
    await prefs.setBool('tutorEnabled', tutorEnabled);
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

    // Calculate current scale from matrix
    final double scale = matrix.getMaxScaleOnAxis();

    // Level of Detail (LOD) for grid
    // Base spacing is 20.0. We want to keep the visual spacing roughly constant.
    // If scale is 0.5, we want spacing to be 40.0.
    // If scale is 0.25, we want spacing to be 80.0.
    double spacing = 20.0;
    if (scale < 0.8) {
      // Find the power of 2 that brings the spacing back to a readable range
      double factor = 1.0 / scale;
      // Round to nearest power of 2 for clean grid jumps (2, 4, 8, 16...)
      double powerOfTwo = 1.0;
      while (powerOfTwo < factor * 0.5) {
        powerOfTwo *= 2;
      }
      spacing *= powerOfTwo;
    }

    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0 / scale; // Keep line width constant on screen

    if (gridType == GridType.grid) {
      // Draw grid (vertical and horizontal lines for math)
      for (
        double x = (minX / spacing).floor() * spacing;
        x <= maxX;
        x += spacing
      ) {
        canvas.drawLine(Offset(x, minY), Offset(x, maxY), paint);
      }

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

String _serializeSketch(Sketch sketch) {
  return jsonEncode(sketch.toJson());
}

Future<String> _runSerialization(Sketch sketch) {
  return Isolate.run(() => _serializeSketch(sketch));
}
