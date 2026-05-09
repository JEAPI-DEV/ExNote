import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:scribble/scribble.dart';
import '../providers/folder_provider.dart';
import '../models/drawing_tool.dart';
import '../models/right_drawer_content.dart';
import '../models/selection.dart';
import '../models/canvas_image.dart';
import '../widgets/note_app_bar.dart';
import '../widgets/note_toolbar.dart';
import '../widgets/ai_chat_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/note_canvas.dart';
import '../controllers/note_settings_controller.dart';
import '../controllers/ai_chat_controller.dart';
import '../utils/undo_redo_manager.dart';
import '../utils/clipboard_manager.dart';
import '../services/note_manager.dart';
import '../services/export/export_service.dart';
import '../services/stylus_shortcut_manager.dart';
import '../services/backup_service.dart';
import '../widgets/dialogs/app_dialogs.dart';

class NoteScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String? exerciseListId;
  final String? selectionId;
  final String noteId;

  const NoteScreen({
    super.key,
    required this.folderId,
    this.exerciseListId,
    this.selectionId,
    required this.noteId,
  });

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  late ValueNotifier<Sketch> sketchNotifier;
  late ValueNotifier<List<SketchLine>> selectionNotifier;
  late ValueNotifier<List<CanvasImage>> canvasImagesNotifier;
  late ValueNotifier<String?> selectedImageIdNotifier;
  late ValueNotifier<Color> colorNotifier;
  late ValueNotifier<double> widthNotifier;
  late ValueNotifier<DrawingTool> toolNotifier;
  final TransformationController _transformationController =
      TransformationController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  RightDrawerContent _rightDrawerContent = RightDrawerContent.settings;

  Timer? _autoSaveTimer;
  Size? _screenshotSize;
  final GlobalKey _exportKey = GlobalKey();

  final NoteSettingsController _settingsController = NoteSettingsController();
  final AiChatController _aiChatController = AiChatController();

  late UndoRedoManager _undoRedoManager;
  late ClipboardManager _clipboardManager;
  late NoteManager _noteManager;

  bool _isLoading = true;
  bool _isApplyingSavedStrokeWidth = false;

  @override
  void initState() {
    super.initState();
    sketchNotifier = ValueNotifier(const Sketch(lines: []));
    selectionNotifier = ValueNotifier([]);
    canvasImagesNotifier = ValueNotifier([]);
    selectedImageIdNotifier = ValueNotifier(null);
    colorNotifier = ValueNotifier(Colors.black);
    widthNotifier = ValueNotifier(2.0);
    toolNotifier = ValueNotifier(DrawingTool.pen);

    StylusShortcutManager.instance.attach(toolNotifier);

    _undoRedoManager = UndoRedoManager(
      sketchNotifier: sketchNotifier,
      onStateChanged: _scheduleAutoSave,
    );

    _clipboardManager = ClipboardManager(
      selectionNotifier: selectionNotifier,
      sketchNotifier: sketchNotifier,
      toolNotifier: toolNotifier,
      undoRedoManager: _undoRedoManager,
      onCopy: () {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
    );

    _noteManager = NoteManager(
      ref: ref,
      folderId: widget.folderId,
      exerciseListId: widget.exerciseListId,
      selectionId: widget.selectionId,
      noteId: widget.noteId,
      sketchNotifier: sketchNotifier,
      imagesNotifier: canvasImagesNotifier,
      undoRedoManager: _undoRedoManager,
    );

    _settingsController.load().then((_) {
      if (mounted) {
        _isApplyingSavedStrokeWidth = true;
        widthNotifier.value = _settingsController.settings.strokeWidth;
        _isApplyingSavedStrokeWidth = false;
      }
    });
    _loadNote();

    widthNotifier.addListener(_saveStrokeWidthSetting);

    selectionNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    selectedImageIdNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadNote() async {
    await _noteManager.loadNote(
      onScreenshotLoaded: (size) {
        if (mounted) {
          setState(() {
            _screenshotSize = size;
          });
        }
      },
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveNote();
    StylusShortcutManager.instance.detach(toolNotifier);
    widthNotifier.removeListener(_saveStrokeWidthSetting);
    sketchNotifier.dispose();
    selectionNotifier.dispose();
    canvasImagesNotifier.dispose();
    selectedImageIdNotifier.dispose();
    colorNotifier.dispose();
    widthNotifier.dispose();
    toolNotifier.dispose();
    _transformationController.dispose();
    _settingsController.dispose();
    _aiChatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folder = ref
        .watch(folderProvider)
        .firstWhere((f) => f.id == widget.folderId);
    final settings = _settingsController.settings;

    String title = 'Note';
    Selection? selection;

    if (widget.exerciseListId != null && widget.selectionId != null) {
      try {
        final list = folder.exerciseLists.firstWhere(
          (l) => l.id == widget.exerciseListId,
        );
        selection = list.selections.firstWhere(
          (s) => s.id == widget.selectionId,
        );
        title = 'Exercise';
      } catch (_) {}
    } else {
      final note = folder.notes[widget.noteId];
      if (note != null && note.name != null) {
        title = note.name!;
      }
    }

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
          key: _scaffoldKey,
          appBar: NoteAppBar(
            title: title,
            onUndo: _undoRedoManager.undo,
            onRedo: _undoRedoManager.redo,
            onCopy: _clipboardManager.copy,
            onPaste: _clipboardManager.paste,
            onAddImage: _addImageToCanvas,
            onExportPng: _exportPng,
            onExportPdf: _exportPdf,
            onSave: () {
              _autoSaveTimer?.cancel();
              _saveNote();
            },
            onSettings: () {
              setState(() => _rightDrawerContent = RightDrawerContent.settings);
              _scaffoldKey.currentState?.openEndDrawer();
            },
            onBack: () async {
              await _saveNote();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            onDelete: selectionNotifier.value.isNotEmpty
                ? _clipboardManager.deleteSelection
                : selectedImageIdNotifier.value != null
                ? _deleteSelectedImage
                : null,
            onChat: () {
              setState(() => _rightDrawerContent = RightDrawerContent.aiChat);
              _scaffoldKey.currentState?.openEndDrawer();
            },
            canUndo: _undoRedoManager.canUndo,
            canRedo: _undoRedoManager.canRedo,
            canCopy: selectionNotifier.value.isNotEmpty,
            canPaste: _clipboardManager.canPaste,
          ),
          endDrawer: _rightDrawerContent == RightDrawerContent.aiChat
              ? SizedBox(
                  width: settings.aiDrawerWidth,
                  child: AiChatDrawer(
                    apiKey: settings.openRouterToken,
                    model: settings.aiModel,
                    isTutorMode: settings.tutorEnabled,
                    submitLastImageOnly: settings.submitLastImageOnly,
                    chatController: _aiChatController,
                    onCaptureContext: _captureCanvas,
                    onWidthChanged: (delta) {
                      _settingsController.update(
                        (s) => s.copyWith(
                          aiDrawerWidth: (s.aiDrawerWidth + delta).clamp(
                            320.0,
                            800.0,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : SettingsDrawer(
                  settingsController: _settingsController,
                  onExportBackup: () async {
                    try {
                      final file = await ExportService.exportToZip();
                      if (mounted) {
                        await Share.shareXFiles([
                          XFile(file.path),
                        ], text: 'ExNote backup');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    }
                  },
                  onImportBackup: () =>
                      BackupService.importFromBackup(context, ref),
                ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  NoteCanvas(
                    transformationController: _transformationController,
                    gridEnabled: settings.gridEnabled,
                    gridType: settings.gridType,
                    gridSpacing: settings.gridSpacing,
                    selection: selection,
                    screenshotSize: _screenshotSize,
                    exportKey: _exportKey,
                    colorNotifier: colorNotifier,
                    widthNotifier: widthNotifier,
                    toolNotifier: toolNotifier,
                    sketchNotifier: sketchNotifier,
                    selectionNotifier: selectionNotifier,
                    canvasImagesNotifier: canvasImagesNotifier,
                    selectedImageIdNotifier: selectedImageIdNotifier,
                    shapeSnappingEnabled: settings.shapeSnappingEnabled,
                    onAction: _undoRedoManager.applyAction,
                    onContentChanged: _scheduleAutoSave,
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: NoteToolbar(
                    colorNotifier: colorNotifier,
                    widthNotifier: widthNotifier,
                    toolNotifier: toolNotifier,
                    sketchNotifier: sketchNotifier,
                    selectionNotifier: selectionNotifier,
                    onAction: _undoRedoManager.applyAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addImageToCanvas() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    try {
      final source = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final originalName = result.files.single.name.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final id = const Uuid().v4();
      final destination = File(
        '${appDir.path}/canvas_image_${id}_$originalName',
      );
      await source.copy(destination.path);

      final bytes = await destination.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();
      final aspect = imageHeight / imageWidth;
      image.dispose();

      const maxInitialWidth = 320.0;
      final initialWidth = imageWidth > maxInitialWidth
          ? maxInitialWidth
          : imageWidth;
      final initialHeight = initialWidth * aspect;

      final canvasImage = CanvasImage(
        id: id,
        path: destination.path,
        left: 100,
        top: 100,
        width: initialWidth,
        height: initialHeight,
      );
      canvasImagesNotifier.value = [...canvasImagesNotifier.value, canvasImage];
      selectedImageIdNotifier.value = id;
      selectionNotifier.value = [];
      toolNotifier.value = DrawingTool.editSelection;
      _scheduleAutoSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image import failed: $e')));
    }
  }

  void _deleteSelectedImage() {
    final selectedId = selectedImageIdNotifier.value;
    if (selectedId == null) return;
    canvasImagesNotifier.value = canvasImagesNotifier.value
        .where((image) => image.id != selectedId)
        .toList();
    selectedImageIdNotifier.value = null;
    _scheduleAutoSave();
  }

  Future<void> _saveNote() async {
    try {
      final screenshot = await _captureCanvas();
      await _noteManager.saveNote(screenshotBase64: screenshot);
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

  void _saveStrokeWidthSetting() {
    if (_isApplyingSavedStrokeWidth) {
      return;
    }

    final width = widthNotifier.value;
    if (_settingsController.settings.strokeWidth == width) {
      return;
    }

    _settingsController.update((s) => s.copyWith(strokeWidth: width));
  }

  Future<void> _exportPng() async {
    try {
      final file = await ExportService.exportToPng(_exportKey, context);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Exported note as PNG');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PNG export failed: $e')));
    }
  }

  Future<void> _exportPdf() async {
    final TextEditingController controller = TextEditingController(
      text: 'exnote_export_${DateTime.now().millisecondsSinceEpoch}',
    );

    final String? filename = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export PDF'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Filename',
            hintText: 'Enter filename (without .pdf)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (filename == null || filename.isEmpty) return;

    ({ui.Image image, Rect rect})? background;
    try {
      background = await _loadExportBackground();
      if (!mounted) return;

      final settings = _settingsController.settings;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      AppDialogs.showProgressDialog(context, message: 'Generating PDF...');

      final file = await ExportService.exportToPdf(
        sketch: sketchNotifier.value,
        context: context,
        filename: filename,
        gridEnabled: settings.gridEnabled,
        gridType: settings.gridType,
        gridSpacing: settings.gridSpacing,
        isDark: isDark,
        backgroundImage: background?.image,
        backgroundRect: background?.rect,
      );
      if (!mounted) return;
      AppDialogs.hideProgressDialog(context);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Exported $filename.pdf');
    } catch (e) {
      if (!mounted) return;
      AppDialogs.hideProgressDialog(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    } finally {
      background?.image.dispose();
    }
  }

  Future<({ui.Image image, Rect rect})?> _loadExportBackground() async {
    if (widget.exerciseListId == null || widget.selectionId == null) {
      return null;
    }

    try {
      final folder = ref
          .read(folderProvider)
          .firstWhere((f) => f.id == widget.folderId);
      final list = folder.exerciseLists.firstWhere(
        (l) => l.id == widget.exerciseListId,
      );
      final selection = list.selections.firstWhere(
        (s) => s.id == widget.selectionId,
      );

      final screenshotPath = selection.screenshotPath;
      if (screenshotPath == null) return null;

      final file = File(screenshotPath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size =
          _screenshotSize ??
          Size(image.width.toDouble() / 2, image.height.toDouble() / 2);

      return (image: image, rect: Rect.fromLTWH(0, 0, size.width, size.height));
    } catch (e) {
      debugPrint('Error loading export background: $e');
      return null;
    }
  }

  Future<String?> _captureCanvas() async {
    return await ExportService.captureCanvas(_exportKey);
  }

  void _scheduleAutoSave() {
    if (mounted) setState(() {});
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNote();
    });
  }
}
