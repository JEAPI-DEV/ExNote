import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';
import '../providers/folder_provider.dart';
import '../models/drawing_tool.dart';
import '../models/selection.dart';
import '../widgets/note_app_bar.dart';
import '../widgets/note_toolbar.dart';
import '../widgets/ai_chat_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/note_canvas.dart';
import '../models/chat_message.dart';
import '../models/grid_type.dart';
import '../models/right_drawer_content.dart';
import '../utils/app_config.dart';
import '../utils/undo_redo_manager.dart';
import '../utils/clipboard_manager.dart';
import '../services/note_manager.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../services/stylus_shortcut_manager.dart';
import '../services/waifu_service.dart';
import '../services/waifu_im_service.dart';
import '../services/waifu_pics_service.dart';
import '../services/backup_service.dart';

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
  bool waifuFetcherEnabled = AppConfig.defaultWaifuFetcherEnabled;
  String waifuProvider = AppConfig.defaultWaifuProvider;
  double waifuImageWidth = AppConfig.defaultWaifuImageWidth;
  String waifuTag = AppConfig.defaultWaifuTag;
  bool waifuNsfw = AppConfig.defaultWaifuNsfw;
  bool shapeSnappingEnabled = AppConfig.defaultShapeSnappingEnabled;
  String? waifuImageUrl;
  final TextEditingController _tokenController = TextEditingController();
  WaifuService? _lastWaifuService;

  // Logic Managers
  late UndoRedoManager _undoRedoManager;
  late ClipboardManager _clipboardManager;
  late NoteManager _noteManager;

  bool _isLoading = true; // AI Chat History
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
          setState(() {}); // Update UI to enable Paste button
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
      undoRedoManager: _undoRedoManager,
    );

    _loadSettings();
    _loadNote();

    selectionNotifier.addListener(() {
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

  Future<void> _fetchWaifuImage() async {
    if (!waifuFetcherEnabled) return;

    final WaifuService service = _getWaifuService();
    final url = await service.fetchWaifuImage(waifuTag, isNsfw: waifuNsfw);
    if (mounted && url != null) {
      setState(() {
        waifuImageUrl = url;
      });
    }
  }

  WaifuService _getWaifuService() {
    _lastWaifuService ??= _createWaifuService(waifuProvider);
    // If provider changed, recreate
    return _lastWaifuService!;
  }

  WaifuService _createWaifuService(String provider) {
    switch (provider) {
      case 'Waifu.pics':
        return WaifuPicsService();
      case 'Waifu.im':
      default:
        return WaifuImService();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveSettings();
    StylusShortcutManager.instance.detach(toolNotifier);
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
              key: _scaffoldKey,
              appBar: NoteAppBar(
                title: title,
                onUndo: _undoRedoManager.undo,
                onRedo: _undoRedoManager.redo,
                onCopy: _clipboardManager.copy,
                onPaste: _clipboardManager.paste,
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
                    ? _clipboardManager.deleteSelection
                    : null,
                onChat: () {
                  setState(
                    () => _rightDrawerContent = RightDrawerContent.aiChat,
                  );
                  _scaffoldKey.currentState?.openEndDrawer();
                },
                canUndo: _undoRedoManager.canUndo,
                canRedo: _undoRedoManager.canRedo,
                canCopy: selectionNotifier.value.isNotEmpty,
                canPaste: _clipboardManager.canPaste,
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
                      waifuFetcherEnabled: waifuFetcherEnabled,
                      waifuProvider: waifuProvider,
                      waifuImageWidth: waifuImageWidth,
                      waifuTag: waifuTag,
                      waifuNsfw: waifuNsfw,
                      shapeSnappingEnabled: shapeSnappingEnabled,
                      availableWaifuTags: waifuNsfw
                          ? _getWaifuService().getNsfwTags()
                          : _getWaifuService().getSfwTags(),
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
                      onWaifuFetcherEnabledChanged: (value) {
                        setState(() {
                          waifuFetcherEnabled = value;
                          if (!value) {
                            waifuImageUrl = null;
                          } else {
                            _fetchWaifuImage();
                          }
                        });
                        _saveSettings();
                      },
                      onWaifuProviderChanged: (value) {
                        setState(() {
                          waifuProvider = value;
                          _lastWaifuService = _createWaifuService(value);
                          waifuTag = waifuNsfw
                              ? _getWaifuService().getNsfwTags().first
                              : _getWaifuService().getSfwTags().first;
                        });
                        _saveSettings();
                      },
                      onWaifuImageWidthChanged: (value) {
                        setState(() {
                          waifuImageWidth = value;
                        });
                        _saveSettings();
                      },
                      onWaifuTagChanged: (value) {
                        setState(() {
                          waifuTag = value;
                        });
                        _saveSettings();
                      },
                      onWaifuNsfwChanged: (value) {
                        setState(() {
                          waifuNsfw = value;
                          // Reset tag if current tag is not in new list
                          final validTags = value
                              ? _getWaifuService().getNsfwTags()
                              : _getWaifuService().getSfwTags();
                          if (!validTags.contains(waifuTag)) {
                            waifuTag = validTags.isNotEmpty
                                ? validTags.first
                                : '';
                          }
                        });
                        _saveSettings();
                      },
                      onShapeSnappingEnabledChanged: (value) {
                        setState(() {
                          shapeSnappingEnabled = value;
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
                        gridEnabled: gridEnabled,
                        gridType: gridType,
                        gridSpacing: gridSpacing,
                        selection: selection,
                        waifuImageUrl: waifuImageUrl,
                        waifuImageWidth: waifuImageWidth,
                        screenshotSize: _screenshotSize,
                        exportKey: _exportKey,
                        colorNotifier: colorNotifier,
                        widthNotifier: widthNotifier,
                        toolNotifier: toolNotifier,
                        sketchNotifier: sketchNotifier,
                        selectionNotifier: selectionNotifier,
                        shapeSnappingEnabled: shapeSnappingEnabled,
                        onAction: _undoRedoManager.applyAction,
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
      },
    );
  }

  Future<void> _saveNote() async {
    try {
      await _noteManager.saveNote();
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

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await ExportService.exportToPdf(
        sketch: sketchNotifier.value,
        context: context,
        filename: filename,
        gridEnabled: gridEnabled,
        gridType: gridType,
        gridSpacing: gridSpacing,
        isDark: Theme.of(context).brightness == Brightness.dark,
      );
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported PDF to ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
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
        waifuFetcherEnabled = settings['waifuFetcherEnabled'];
        waifuProvider = settings['waifuProvider'];
        waifuImageWidth = settings['waifuImageWidth'];
        waifuTag = settings['waifuTag'];
        waifuNsfw = settings['waifuNsfw'];
        shapeSnappingEnabled = settings['shapeSnappingEnabled'];

        // Ensure service is initialized with correct provider before fetch
        _lastWaifuService = _createWaifuService(waifuProvider);
      });
      if (waifuFetcherEnabled) {
        _fetchWaifuImage();
      }
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
      waifuFetcherEnabled: waifuFetcherEnabled,
      waifuProvider: waifuProvider,
      waifuImageWidth: waifuImageWidth,
      waifuTag: waifuTag,
      waifuNsfw: waifuNsfw,
      shapeSnappingEnabled: shapeSnappingEnabled,
    );
  }

  void _scheduleAutoSave() {
    if (mounted) setState(() {});
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNote();
    });
  }
}
