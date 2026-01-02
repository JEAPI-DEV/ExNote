import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';
import 'package:flutter/rendering.dart';
import '../providers/folder_provider.dart';
import '../widgets/fast_drawing_canvas.dart';
import '../models/drawing_tool.dart';
import '../widgets/note_app_bar.dart';
import '../widgets/note_toolbar.dart';
import '../widgets/ai_chat_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../models/undo_action.dart';
import '../models/chat_message.dart';
import '../models/grid_type.dart';
import '../models/right_drawer_content.dart';
import '../widgets/grid_painter.dart';
import '../utils/sketch_serializer.dart';
import '../utils/app_config.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';

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
  double gridSpacing = AppConfig.defaultGridSpacing;
  RightDrawerContent _rightDrawerContent = RightDrawerContent.settings;

  Timer? _autoSaveTimer;
  Size? _screenshotSize;
  final GlobalKey _exportKey = GlobalKey();

  // AI Settings
  String openRouterToken = '';
  String aiModel = AppConfig.defaultAiModel;
  bool tutorEnabled = AppConfig.defaultTutorEnabled;
  bool submitLastImageOnly = AppConfig.defaultSubmitLastImageOnly;
  double aiDrawerWidth = AppConfig.defaultAiDrawerWidth;
  final TextEditingController _tokenController = TextEditingController();

  // Undo/Redo History (Git-like)
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];
  final ValueNotifier<int> _historyNotifier = ValueNotifier(0);
  bool _isLoading = true;

  // Clipboard
  List<SketchLine> _clipboard = [];

  // AI Chat History
  final List<ChatMessage> _aiChatHistory = [];
  final TextEditingController _aiChatController = TextEditingController();

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

    selectionNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _applyAction(UndoAction action) {
    _undoStack.add(action);
    _redoStack.clear();
    _historyNotifier.value++;
    _scheduleAutoSave();
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      final action = _undoStack.removeLast();
      final currentLines = List<SketchLine>.from(sketchNotifier.value.lines);
      action.undo(currentLines);
      sketchNotifier.value = Sketch(lines: currentLines);
      _redoStack.add(action);
      _historyNotifier.value++;
      _scheduleAutoSave();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      final action = _redoStack.removeLast();
      final currentLines = List<SketchLine>.from(sketchNotifier.value.lines);
      action.redo(currentLines);
      sketchNotifier.value = Sketch(lines: currentLines);
      _undoStack.add(action);
      _historyNotifier.value++;
      _scheduleAutoSave();
    }
  }

  void _deleteSelection() {
    final selectedLines = selectionNotifier.value;
    if (selectedLines.isEmpty) return;

    final currentSketch = sketchNotifier.value;
    final remainingLines = <SketchLine>[];
    final removedLines = <SketchLine>[];
    final originalIndices = <int>[];

    for (int i = 0; i < currentSketch.lines.length; i++) {
      final line = currentSketch.lines[i];
      if (selectedLines.contains(line)) {
        removedLines.add(line);
        originalIndices.add(i);
      } else {
        remainingLines.add(line);
      }
    }

    sketchNotifier.value = Sketch(lines: remainingLines);
    _applyAction(RemoveLinesAction(removedLines, originalIndices));
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
    _applyAction(AddLinesAction(pastedLines));

    // Select pasted lines
    selectionNotifier.value = pastedLines;
    toolNotifier.value = DrawingTool.selection;
  }

  Future<void> _loadNote() async {
    try {
      final folder = ref
          .read(folderProvider)
          .firstWhere((f) => f.id == widget.folderId);

      // Load sketch data from separate file
      String? scribbleData = await ref
          .read(folderProvider.notifier)
          .loadNoteData(widget.noteId);
      debugPrint(
        'DEBUG: loadNoteData for ${widget.noteId} returned: ${scribbleData?.length ?? "null"} chars',
      );

      // Migration Path: If new file is missing, check legacy data in folders.json
      if (scribbleData == null || scribbleData.isEmpty) {
        final legacyNote = folder.notes[widget.noteId];
        debugPrint(
          'DEBUG: legacyNote for ${widget.noteId} exists: ${legacyNote != null}',
        );
        if (legacyNote != null) {
          debugPrint(
            'DEBUG: legacyNote.scribbleData length: ${legacyNote.scribbleData.length}',
          );
        }

        if (legacyNote != null && legacyNote.scribbleData.isNotEmpty) {
          debugPrint('Migrating legacy note data for ${widget.noteId}');
          scribbleData = legacyNote.scribbleData;
          // Save to new format immediately
          await ref
              .read(folderProvider.notifier)
              .updateNote(
                widget.folderId,
                widget.noteId,
                scribbleData,
                legacyNote.screenshotPath,
              );
        }
      }

      if (scribbleData != null && scribbleData.isNotEmpty) {
        try {
          final sketchJson = jsonDecode(scribbleData) as Map<String, dynamic>;
          final loadedSketch = Sketch.fromJson(sketchJson);

          sketchNotifier.value = loadedSketch;

          // Reset history to start with this loaded sketch
          _undoStack.clear();
          _redoStack.clear();
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
    _aiChatController.dispose();
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

    return Builder(
      builder: (context) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (didPop) {
              await _saveNote();
            }
          },
          child: Listener(
            onPointerDown: (event) {
              if (FocusScope.of(context).hasFocus) {
                FocusScope.of(context).unfocus();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: Scaffold(
              key: _scaffoldKey, // Assign GlobalKey
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: ValueListenableBuilder<int>(
                  valueListenable: _historyNotifier,
                  builder: (context, _, __) {
                    return ValueListenableBuilder<List<SketchLine>>(
                      valueListenable: selectionNotifier,
                      builder: (context, selectedLines, _) {
                        return NoteAppBar(
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
                              () => _rightDrawerContent =
                                  RightDrawerContent.settings,
                            );
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                          onBack: () async {
                            await _saveNote();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          onDelete: selectedLines.isNotEmpty
                              ? _deleteSelection
                              : null,
                          onChat: () {
                            setState(
                              () => _rightDrawerContent =
                                  RightDrawerContent.aiChat,
                            );
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                          canUndo: _undoStack.isNotEmpty,
                          canRedo: _redoStack.isNotEmpty,
                          canCopy: selectedLines.isNotEmpty,
                          canPaste: _clipboard.isNotEmpty,
                        );
                      },
                    );
                  },
                ),
              ),
              endDrawer: _rightDrawerContent == RightDrawerContent.aiChat
                  ? SizedBox(
                      width: aiDrawerWidth,
                      child: AiChatDrawer(
                        apiKey: openRouterToken,
                        model: aiModel,
                        isTutorMode: tutorEnabled,
                        submitLastImageOnly: submitLastImageOnly,
                        history: _aiChatHistory,
                        controller: _aiChatController,
                        onCaptureContext: _captureCanvas,
                        onClearHistory: () {
                          setState(() {
                            _aiChatHistory.clear();
                            _aiChatHistory.add(
                              ChatMessage(
                                text: tutorEnabled
                                    ? "Hello! I'm your tutor. How can I help you with your notes today?"
                                    : "Hello! How can I help you today?",
                                isAi: true,
                              ),
                            );
                          });
                        },
                        onWidthChanged: (delta) {
                          setState(() {
                            aiDrawerWidth = (aiDrawerWidth + delta).clamp(
                              320.0,
                              800.0,
                            );
                          });
                          _saveSettings();
                        },
                      ),
                    )
                  : SettingsDrawer(
                      gridEnabled: gridEnabled,
                      gridType: gridType,
                      gridSpacing: gridSpacing,
                      aiModel: aiModel,
                      tutorEnabled: tutorEnabled,
                      submitLastImageOnly: submitLastImageOnly,
                      tokenController: _tokenController,
                      onGridEnabledChanged: (value) {
                        setState(() {
                          gridEnabled = value;
                        });
                        _saveSettings();
                      },
                      onGridTypeChanged: (value) {
                        setState(() {
                          gridType = value;
                        });
                        _saveSettings();
                      },
                      onGridSpacingChanged: (value) {
                        setState(() {
                          gridSpacing = value;
                        });
                        _saveSettings();
                      },
                      onTokenChanged: (value) {
                        openRouterToken = value;
                        _saveSettings();
                      },
                      onAiModelChanged: (value) {
                        setState(() {
                          aiModel = value;
                        });
                        _saveSettings();
                      },
                      onTutorEnabledChanged: (value) {
                        setState(() {
                          tutorEnabled = value;
                        });
                        _saveSettings();
                      },
                      onSubmitLastImageOnlyChanged: (value) {
                        setState(() {
                          submitLastImageOnly = value;
                        });
                        _saveSettings();
                      },
                      onExportBackup: () async {
                        try {
                          final file = await ExportService.exportToZip();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Backup saved to ${file.path}'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Backup failed: $e')),
                            );
                          }
                        }
                      },
                    ),
              body: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: Stack(
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
                                            matrix:
                                                _transformationController.value,
                                            gridType: gridType,
                                            spacing: gridSpacing,
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
                                                    sketchNotifier:
                                                        sketchNotifier,
                                                    selectionNotifier:
                                                        selectionNotifier,
                                                    currentColor: color,
                                                    currentWidth: width,
                                                    currentTool: tool,
                                                    scale:
                                                        _transformationController
                                                            .value
                                                            .getMaxScaleOnAxis(),
                                                    onAction: _applyAction,
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveNote() async {
    try {
      final sketch = sketchNotifier.value;
      final jsonSketch = await runSerialization(sketch);

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
      final file = await ExportService.exportToPng(_exportKey, context);
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
      final file = await ExportService.exportToPdf(_exportKey, context);
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

  Future<String?> _captureCanvas() async {
    return await ExportService.captureCanvas(_exportKey);
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.loadSettings();
    if (mounted) {
      setState(() {
        widthNotifier.value = settings['strokeWidth'];
        gridEnabled = settings['gridEnabled'];
        gridType = settings['gridType'];
        gridSpacing = settings['gridSpacing'];
        openRouterToken = settings['openRouterToken'];
        aiModel = settings['aiModel'];
        _tokenController.text = openRouterToken;
        tutorEnabled = settings['tutorEnabled'];
        submitLastImageOnly = settings['submitLastImageOnly'];
        aiDrawerWidth = settings['aiDrawerWidth'];
      });
    }
  }

  Future<void> _saveSettings() async {
    await SettingsService.saveSettings(
      strokeWidth: widthNotifier.value,
      gridEnabled: gridEnabled,
      gridType: gridType,
      gridSpacing: gridSpacing,
      openRouterToken: openRouterToken,
      aiModel: aiModel,
      tutorEnabled: tutorEnabled,
      submitLastImageOnly: submitLastImageOnly,
      aiDrawerWidth: aiDrawerWidth,
    );
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNote();
    });
  }
}
