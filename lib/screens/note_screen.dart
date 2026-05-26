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
import '../models/note_settings.dart';
import '../models/undo_action.dart';
import '../widgets/note_app_bar.dart';
import '../widgets/note_toolbar.dart';
import '../widgets/edit_selection_controls.dart';
import '../widgets/ai_chat_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/note_canvas.dart';
import '../controllers/note_settings_controller.dart';
import '../controllers/ai_chat_controller.dart';
import '../utils/undo_redo_manager.dart';
import '../utils/clipboard_manager.dart';
import '../utils/sketch_bounds.dart';
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
  static const Size _horizontalEditPopupPanelSize = Size(292.0, 64.0);
  static const Size _verticalEditPopupPanelSize = Size(64.0, 292.0);

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
  final GlobalKey _noteBodyStackKey = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();
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
  bool _isStrokeActive = false;
  bool _isAutoSaving = false;
  bool _isEditingNoteLook = false;
  Color _editColor = Colors.black;
  double _editWidth = 2.0;
  Size _toolbarSize = Size.zero;
  Offset? _toolbarDragGrabOffset;
  Offset? _editPopupDragGrabOffset;
  Offset? _draftToolbarPosition;
  Offset? _draftEditPopupPosition;
  NoteToolbarOrientation? _draftToolbarOrientation;
  NoteToolbarOrientation? _draftEditPopupOrientation;

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
      final selected = selectionNotifier.value;
      if (selected.isNotEmpty) {
        _editColor = Color(selected.first.color);
        _editWidth = selected.first.width;
      }
      if (mounted) setState(() {});
    });
    toolNotifier.addListener(_handleToolChanged);
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
    _saveNote(captureThumbnail: false);
    StylusShortcutManager.instance.detach(toolNotifier);
    widthNotifier.removeListener(_saveStrokeWidthSetting);
    toolNotifier.removeListener(_handleToolChanged);
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
                  onAdjustNoteLook: _startNoteLookEdit,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  key: _noteBodyStackKey,
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
                        onStrokeActivityChanged: _handleStrokeActivityChanged,
                      ),
                    _buildToolbarLayer(constraints, settings),
                    _buildEditSelectionControlsLayer(constraints, settings),
                    if (_isEditingNoteLook) _buildNoteLookEditor(settings),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarLayer(BoxConstraints constraints, NoteSettings settings) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateToolbarSize());

    final orientation = _isEditingNoteLook
        ? _draftToolbarOrientation ?? settings.toolbarOrientation
        : settings.toolbarOrientation;
    final position = _currentToolbarPosition(settings);
    final left = _positionedToolbarLeft(constraints, position.dx);
    final top = _positionedToolbarTop(constraints, position.dy);
    final toolbar = KeyedSubtree(
      key: _toolbarKey,
      child: NoteToolbar(
        colorNotifier: colorNotifier,
        widthNotifier: widthNotifier,
        toolNotifier: toolNotifier,
        sketchNotifier: sketchNotifier,
        selectionNotifier: selectionNotifier,
        onAction: _undoRedoManager.applyAction,
        orientation: orientation,
      ),
    );

    return Positioned(
      left: left,
      top: top,
      child: _isEditingNoteLook
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  _startToolbarDrag(details.globalPosition, Offset(left, top)),
              onPanUpdate: (details) =>
                  _updateToolbarDrag(constraints, details.globalPosition),
              onPanEnd: (_) => _endToolbarDrag(),
              onPanCancel: _endToolbarDrag,
              child: AbsorbPointer(child: toolbar),
            )
          : toolbar,
    );
  }

  Widget _buildEditSelectionControlsLayer(
    BoxConstraints constraints,
    NoteSettings settings,
  ) {
    final shouldShowPopup =
        _isEditingNoteLook ||
        (toolNotifier.value == DrawingTool.editSelection &&
            selectionNotifier.value.isNotEmpty);
    if (!shouldShowPopup) {
      return const SizedBox.shrink();
    }

    final topLeft = _currentEditPopupTopLeft(constraints, settings);
    final orientation = _currentEditPopupOrientation(settings);
    final controls = EditSelectionControls(
      editColor: _editColor,
      editWidth: _editWidth,
      orientation: orientation,
      onColorChanged: (color) {
        if (_isEditingNoteLook) return;
        setState(() => _editColor = color);
        _applyStyleToSelection(color: color);
      },
      onWidthChanged: (value) {
        if (_isEditingNoteLook) return;
        setState(() => _editWidth = value);
      },
      onWidthChangeEnd: () {
        if (_isEditingNoteLook) return;
        _applyStyleToSelection(strokeWidth: _editWidth);
      },
      onMirrorX: () {
        if (_isEditingNoteLook) return;
        _mirrorSelection(mirrorOverXAxis: true);
      },
      onMirrorY: () {
        if (_isEditingNoteLook) return;
        _mirrorSelection(mirrorOverXAxis: false);
      },
    );

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: _isEditingNoteLook
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  _startEditPopupDrag(details.globalPosition, topLeft),
              onPanUpdate: (details) =>
                  _updateEditPopupDrag(constraints, details.globalPosition),
              onPanEnd: (_) => _endEditPopupDrag(),
              onPanCancel: _endEditPopupDrag,
              child: AbsorbPointer(child: controls),
            )
          : controls,
    );
  }

  Widget _buildNoteLookEditor(NoteSettings settings) {
    final orientation = _draftToolbarOrientation ?? settings.toolbarOrientation;
    final editPopupOrientation = _currentEditPopupOrientation(settings);

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.open_with),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Adjust note look',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Drag the toolbar and edit popup, then confirm to save.',
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toolbar',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  _buildOrientationSelector(
                    orientation,
                    (value) => setState(() {
                      _draftToolbarOrientation = value;
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit bar',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  _buildOrientationSelector(
                    editPopupOrientation,
                    (value) => setState(() {
                      _draftEditPopupOrientation = value;
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _cancelNoteLookEdit,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _confirmNoteLookEdit,
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrientationSelector(
    NoteToolbarOrientation orientation,
    ValueChanged<NoteToolbarOrientation> onChanged,
  ) {
    return SegmentedButton<NoteToolbarOrientation>(
      segments: const [
        ButtonSegment(
          value: NoteToolbarOrientation.horizontal,
          label: Text('Horizontal'),
          icon: Icon(Icons.view_week),
        ),
        ButtonSegment(
          value: NoteToolbarOrientation.vertical,
          label: Text('Vertical'),
          icon: Icon(Icons.view_agenda),
        ),
      ],
      selected: {orientation},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }

  Offset _currentToolbarPosition(NoteSettings settings) {
    if (_isEditingNoteLook) {
      return _draftToolbarPosition ??
          Offset(settings.toolbarPositionX, settings.toolbarPositionY);
    }

    return Offset(settings.toolbarPositionX, settings.toolbarPositionY);
  }

  double _positionedToolbarLeft(BoxConstraints constraints, double x) {
    final maxLeft = (constraints.maxWidth - _toolbarSize.width)
        .clamp(0.0, double.infinity)
        .toDouble();
    return x.clamp(0.0, 1.0).toDouble() * maxLeft;
  }

  double _positionedToolbarTop(BoxConstraints constraints, double y) {
    final maxTop = (constraints.maxHeight - _toolbarSize.height)
        .clamp(0.0, double.infinity)
        .toDouble();
    return y.clamp(0.0, 1.0).toDouble() * maxTop;
  }

  void _moveDraftToolbar(BoxConstraints constraints, Offset topLeft) {
    final maxLeft = (constraints.maxWidth - _toolbarSize.width)
        .clamp(0.0, double.infinity)
        .toDouble();
    final maxTop = (constraints.maxHeight - _toolbarSize.height)
        .clamp(0.0, double.infinity)
        .toDouble();
    final left = topLeft.dx.clamp(0.0, maxLeft).toDouble();
    final top = topLeft.dy.clamp(0.0, maxTop).toDouble();

    setState(() {
      _draftToolbarPosition = Offset(
        maxLeft == 0 ? 0 : left / maxLeft,
        maxTop == 0 ? 0 : top / maxTop,
      );
    });
  }

  void _startToolbarDrag(Offset globalPosition, Offset topLeft) {
    final local = _globalToNoteBodyLocal(globalPosition);
    if (local == null) return;
    _toolbarDragGrabOffset = local - topLeft;
  }

  void _updateToolbarDrag(BoxConstraints constraints, Offset globalPosition) {
    final local = _globalToNoteBodyLocal(globalPosition);
    final grabOffset = _toolbarDragGrabOffset;
    if (local == null || grabOffset == null) return;
    _moveDraftToolbar(constraints, local - grabOffset);
  }

  void _endToolbarDrag() {
    _toolbarDragGrabOffset = null;
  }

  Offset? _globalToNoteBodyLocal(Offset globalPosition) {
    final renderBox =
        _noteBodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.globalToLocal(globalPosition);
  }

  Offset _currentEditPopupTopLeft(
    BoxConstraints constraints,
    NoteSettings settings,
  ) {
    final panelSize = _currentEditPopupPanelSize(settings);
    final normalized = _isEditingNoteLook
        ? _draftEditPopupPosition ?? _savedEditPopupPosition(settings)
        : _savedEditPopupPosition(settings);

    if (normalized != null) {
      return _editPopupTopLeftFromNormalized(
        constraints,
        normalized,
        panelSize,
      );
    }

    return _autoEditPopupTopLeft(constraints, settings, panelSize);
  }

  NoteToolbarOrientation _currentEditPopupOrientation(NoteSettings settings) {
    return _isEditingNoteLook
        ? _draftEditPopupOrientation ?? settings.editPopupOrientation
        : settings.editPopupOrientation;
  }

  Size _currentEditPopupPanelSize(NoteSettings settings) {
    return _currentEditPopupOrientation(settings) ==
            NoteToolbarOrientation.horizontal
        ? _horizontalEditPopupPanelSize
        : _verticalEditPopupPanelSize;
  }

  Offset? _savedEditPopupPosition(NoteSettings settings) {
    final x = settings.editPopupPositionX;
    final y = settings.editPopupPositionY;
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Offset _autoEditPopupTopLeft(
    BoxConstraints constraints,
    NoteSettings settings,
    Size panelSize,
  ) {
    final position = _currentToolbarPosition(settings);
    final toolbarLeft = _positionedToolbarLeft(constraints, position.dx);
    final toolbarTop = _positionedToolbarTop(constraints, position.dy);
    const gap = 12.0;
    final rightLeft = toolbarLeft + _toolbarSize.width + gap;
    final hasRightSpace = rightLeft + panelSize.width <= constraints.maxWidth;
    final maxLeft = (constraints.maxWidth - panelSize.width)
        .clamp(0.0, double.infinity)
        .toDouble();
    final maxTop = (constraints.maxHeight - panelSize.height)
        .clamp(0.0, double.infinity)
        .toDouble();
    final left = hasRightSpace
        ? rightLeft.clamp(0.0, maxLeft).toDouble()
        : (toolbarLeft - panelSize.width - gap).clamp(0.0, maxLeft).toDouble();
    final top = (toolbarTop + (_toolbarSize.height - panelSize.height) / 2)
        .clamp(0.0, maxTop)
        .toDouble();

    return Offset(left, top);
  }

  Offset _editPopupTopLeftFromNormalized(
    BoxConstraints constraints,
    Offset normalized,
    Size panelSize,
  ) {
    final maxLeft = (constraints.maxWidth - panelSize.width)
        .clamp(0.0, double.infinity)
        .toDouble();
    final maxTop = (constraints.maxHeight - panelSize.height)
        .clamp(0.0, double.infinity)
        .toDouble();

    return Offset(
      normalized.dx.clamp(0.0, 1.0).toDouble() * maxLeft,
      normalized.dy.clamp(0.0, 1.0).toDouble() * maxTop,
    );
  }

  void _moveDraftEditPopup(BoxConstraints constraints, Offset topLeft) {
    final panelSize =
        _draftEditPopupOrientation == NoteToolbarOrientation.vertical
        ? _verticalEditPopupPanelSize
        : _horizontalEditPopupPanelSize;
    final maxLeft = (constraints.maxWidth - panelSize.width)
        .clamp(0.0, double.infinity)
        .toDouble();
    final maxTop = (constraints.maxHeight - panelSize.height)
        .clamp(0.0, double.infinity)
        .toDouble();
    final left = topLeft.dx.clamp(0.0, maxLeft).toDouble();
    final top = topLeft.dy.clamp(0.0, maxTop).toDouble();

    setState(() {
      _draftEditPopupPosition = Offset(
        maxLeft == 0 ? 0 : left / maxLeft,
        maxTop == 0 ? 0 : top / maxTop,
      );
    });
  }

  void _startEditPopupDrag(Offset globalPosition, Offset topLeft) {
    final local = _globalToNoteBodyLocal(globalPosition);
    if (local == null) return;
    _editPopupDragGrabOffset = local - topLeft;
  }

  void _updateEditPopupDrag(BoxConstraints constraints, Offset globalPosition) {
    final local = _globalToNoteBodyLocal(globalPosition);
    final grabOffset = _editPopupDragGrabOffset;
    if (local == null || grabOffset == null) return;
    _moveDraftEditPopup(constraints, local - grabOffset);
  }

  void _endEditPopupDrag() {
    _editPopupDragGrabOffset = null;
  }

  void _updateToolbarSize() {
    if (!mounted) return;

    final renderBox =
        _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    if (_toolbarSize == size) return;

    setState(() {
      _toolbarSize = size;
    });
  }

  void _startNoteLookEdit() {
    final settings = _settingsController.settings;
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    setState(() {
      _draftToolbarPosition = Offset(
        settings.toolbarPositionX,
        settings.toolbarPositionY,
      );
      _draftEditPopupPosition = _savedEditPopupPosition(settings);
      _draftToolbarOrientation = settings.toolbarOrientation;
      _draftEditPopupOrientation = settings.editPopupOrientation;
      _isEditingNoteLook = true;
    });
  }

  void _cancelNoteLookEdit() {
    setState(() {
      _isEditingNoteLook = false;
      _draftToolbarPosition = null;
      _draftEditPopupPosition = null;
      _draftToolbarOrientation = null;
      _draftEditPopupOrientation = null;
      _toolbarDragGrabOffset = null;
      _editPopupDragGrabOffset = null;
    });
  }

  void _confirmNoteLookEdit() {
    final draftPosition = _draftToolbarPosition;
    final draftEditPopupPosition = _draftEditPopupPosition;
    final draftOrientation = _draftToolbarOrientation;
    final draftEditPopupOrientation = _draftEditPopupOrientation;

    if (draftPosition != null ||
        draftEditPopupPosition != null ||
        draftOrientation != null ||
        draftEditPopupOrientation != null) {
      _settingsController.update(
        (settings) => settings.copyWith(
          toolbarPositionX: draftPosition?.dx.clamp(0.0, 1.0).toDouble(),
          toolbarPositionY: draftPosition?.dy.clamp(0.0, 1.0).toDouble(),
          toolbarOrientation: draftOrientation,
          editPopupPositionX: draftEditPopupPosition?.dx
              .clamp(0.0, 1.0)
              .toDouble(),
          editPopupPositionY: draftEditPopupPosition?.dy
              .clamp(0.0, 1.0)
              .toDouble(),
          editPopupOrientation: draftEditPopupOrientation,
        ),
      );
    }

    setState(() {
      _isEditingNoteLook = false;
      _draftToolbarPosition = null;
      _draftEditPopupPosition = null;
      _draftToolbarOrientation = null;
      _draftEditPopupOrientation = null;
      _toolbarDragGrabOffset = null;
      _editPopupDragGrabOffset = null;
    });
  }

  void _handleToolChanged() {
    if (mounted) setState(() {});
  }

  void _applyStyleToSelection({Color? color, double? strokeWidth}) {
    final selected = selectionNotifier.value;
    if (selected.isEmpty) return;

    final sketch = sketchNotifier.value;
    final selectedSet = selected.toSet();
    final updatedLines = [...sketch.lines];
    final oldLines = <SketchLine>[];
    final newLines = <SketchLine>[];
    final indices = <int>[];

    for (int i = 0; i < sketch.lines.length; i++) {
      final line = sketch.lines[i];
      if (selectedSet.contains(line)) {
        oldLines.add(line);
        final updated = line.copyWith(
          color: color?.toARGB32() ?? line.color,
          width: strokeWidth ?? line.width,
        );
        newLines.add(updated);
        updatedLines[i] = updated;
        indices.add(i);
      }
    }

    if (newLines.isEmpty) return;

    sketchNotifier.value = Sketch(lines: updatedLines);
    selectionNotifier.value = newLines;
    _undoRedoManager.applyAction(
      TransformLinesAction(oldLines, newLines, indices),
    );
  }

  void _mirrorSelection({required bool mirrorOverXAxis}) {
    final selected = selectionNotifier.value;
    if (selected.isEmpty) return;

    final bounds = computeLineBounds(selected);
    if (bounds == Rect.zero) return;

    final sketch = sketchNotifier.value;
    final selectedSet = selected.toSet();
    final updatedLines = [...sketch.lines];
    final oldLines = <SketchLine>[];
    final newLines = <SketchLine>[];
    final indices = <int>[];

    for (int i = 0; i < sketch.lines.length; i++) {
      final line = sketch.lines[i];
      if (!selectedSet.contains(line)) continue;

      oldLines.add(line);
      final updated = line.copyWith(
        points: line.points.map((p) {
          if (mirrorOverXAxis) {
            return Point(
              p.x,
              bounds.center.dy - (p.y - bounds.center.dy),
              pressure: p.pressure,
            );
          }

          return Point(
            bounds.center.dx - (p.x - bounds.center.dx),
            p.y,
            pressure: p.pressure,
          );
        }).toList(),
      );
      newLines.add(updated);
      updatedLines[i] = updated;
      indices.add(i);
    }

    if (newLines.isEmpty) return;

    sketchNotifier.value = Sketch(lines: updatedLines);
    selectionNotifier.value = newLines;
    _undoRedoManager.applyAction(
      TransformLinesAction(oldLines, newLines, indices),
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

  Future<void> _saveNote({bool captureThumbnail = true}) async {
    try {
      final screenshot = captureThumbnail ? await _captureCanvas() : null;
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

  void _handleStrokeActivityChanged(bool isActive) {
    _isStrokeActive = isActive;
    if (isActive) {
      _autoSaveTimer?.cancel();
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
    _autoSaveTimer = Timer(const Duration(seconds: 2), _runAutoSave);
  }

  void _runAutoSave() {
    if (_isStrokeActive || _isAutoSaving) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 750), _runAutoSave);
      return;
    }

    _isAutoSaving = true;
    _saveNote(captureThumbnail: false).whenComplete(() {
      _isAutoSaving = false;
      if (_isStrokeActive) {
        _autoSaveTimer?.cancel();
        _autoSaveTimer = Timer(const Duration(milliseconds: 750), _runAutoSave);
      }
    });
  }
}
