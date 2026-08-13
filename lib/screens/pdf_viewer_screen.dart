import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import '../providers/folder_provider.dart';
import '../models/selection.dart';
import '../controllers/pdf_annotation_controller.dart';
import '../utils/pdf_coordinate_mapper.dart';
import '../services/pdf/pdf_screenshot_service.dart';
import '../widgets/selection_overlay.dart';
import '../widgets/link_overlay_painter.dart';
import '../widgets/pdf_annotation_overlay.dart';
import '../widgets/pdf_annotation_toolbar.dart';
import 'note_screen.dart';

enum _PdfViewerMode { view, select, annotate }

/// Multiplier applied to a page's native size when rendering it for display.
/// Higher values produce crisper text at the cost of more memory per page.
const double _pdfRenderScale = 3.0;

/// Renders a page as lossless PNG at [_pdfRenderScale] resolution so text stays
/// sharp when the page is scaled down to fit the viewport.
Future<PdfPageImage?> _renderPdfPage(PdfPage page) => page.render(
      width: page.width * _pdfRenderScale,
      height: page.height * _pdfRenderScale,
      format: PdfPageImageFormat.png,
      backgroundColor: '#ffffff',
    );

class PDFViewerScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String exerciseListId;

  const PDFViewerScreen({
    super.key,
    required this.folderId,
    required this.exerciseListId,
  });

  @override
  ConsumerState<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends ConsumerState<PDFViewerScreen> {
  late PdfController _pdfController;
  late PdfAnnotationController _annotationController;
  _PdfViewerMode _mode = _PdfViewerMode.view;
  Rect? _selectionRect;
  double _scrollOffset = 0;
  final GlobalKey _pdfViewKey = GlobalKey();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  List<double> _pageWidths = [];
  List<double> _pageHeights = [];
  bool _isProcessing = false;
  int _currentPageNumber = 1;
  Timer? _annotationSaveTimer;

  @override
  void initState() {
    super.initState();
    final folder = ref
        .read(folderProvider)
        .firstWhere((f) => f.id == widget.folderId);
    final list = folder.exerciseLists.firstWhere(
      (l) => l.id == widget.exerciseListId,
    );

    _pdfController = PdfController(
      document: PdfDocument.openFile(list.pdfPath),
    );

    _annotationController = PdfAnnotationController(
      onContentChanged: _scheduleAnnotationSave,
    );
    _annotationController.load(list.annotations);

    _loadPageSizes();
  }

  Future<void> _loadPageSizes() async {
    final document = await _pdfController.document;
    final pages = document.pagesCount;
    final widths = <double>[];
    final heights = <double>[];
    for (int i = 1; i <= pages; i++) {
      final page = await document.getPage(i);
      widths.add(page.width.toDouble());
      heights.add(page.height.toDouble());
      page.close();
    }
    setState(() {
      _pageWidths = widths;
      _pageHeights = heights;
    });
  }

  @override
  void dispose() {
    _annotationSaveTimer?.cancel();
    _saveAnnotations();
    _annotationController.dispose();
    _pdfController.dispose();
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(list.name),
        backgroundColor: _mode == _PdfViewerMode.select
            ? Colors.red.withOpacity(0.1)
            : _mode == _PdfViewerMode.annotate
            ? Colors.blue.withOpacity(0.1)
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewSize = constraints.biggest;

          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    setState(() {
                      _scrollOffset = notification.metrics.pixels;
                    });
                  }
                  return false;
                },
                child: RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: ColorFiltered(
                    colorFilter: isDark
                        ? const ColorFilter.matrix([
                            -1,
                            0,
                            0,
                            0,
                            255,
                            0,
                            -1,
                            0,
                            0,
                            255,
                            0,
                            0,
                            -1,
                            0,
                            255,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ])
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          ),
                    child: PdfView(
                      key: _pdfViewKey,
                      controller: _pdfController,
                      scrollDirection: Axis.vertical,
                      pageSnapping: false,
                      renderer: _renderPdfPage,
                      onPageChanged: (page) {
                        _currentPageNumber = page;
                      },
                      physics: _mode == _PdfViewerMode.view
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      builders: PdfViewBuilders<DefaultBuilderOptions>(
                        options: const DefaultBuilderOptions(),
                        pageBuilder:
                            (
                              BuildContext context,
                              Future<PdfPageImage> pageImage,
                              int index,
                              PdfDocument document,
                            ) {
                              return PhotoViewGalleryPageOptions(
                                imageProvider: PdfPageImageProvider(
                                  pageImage,
                                  index,
                                  document.id,
                                ),
                                minScale:
                                    PhotoViewComputedScale.contained * 1.0,
                                maxScale:
                                    PhotoViewComputedScale.contained * 1.0,
                                initialScale:
                                    PhotoViewComputedScale.contained * 1.0,
                                disableGestures: true,
                                filterQuality: FilterQuality.high,
                                heroAttributes: PhotoViewHeroAttributes(
                                  tag: '${document.id}-$index',
                                ),
                              );
                            },
                      ),
                    ),
                  ),
                ),
              ),
              PdfAnnotationOverlay(
                controller: _annotationController,
                pageWidths: _pageWidths,
                pageHeights: _pageHeights,
                scrollOffset: _scrollOffset,
                viewSize: viewSize,
                interactive: _mode == _PdfViewerMode.annotate,
                isDark: isDark,
              ),
              if (_mode == _PdfViewerMode.select)
                Positioned.fill(
                  child: ExerciseSelectionOverlay(
                    rect: _selectionRect,
                    onRectChanged: (rect) {
                      setState(() {
                        _selectionRect = rect;
                      });
                    },
                    onConfirm: _confirmSelection,
                    onCancel: () {
                      setState(() {
                        _mode = _PdfViewerMode.view;
                        _selectionRect = null;
                      });
                    },
                  ),
                ),
              if (_mode == _PdfViewerMode.annotate)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: PdfAnnotationToolbar(
                        controller: _annotationController,
                        pageCount: _pageWidths.isEmpty ? 1 : _pageWidths.length,
                        onPreviousPage: () => _goToAnnotatePage(
                          _annotationController.activePageIndex - 1,
                        ),
                        onNextPage: () => _goToAnnotatePage(
                          _annotationController.activePageIndex + 1,
                        ),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                ignoring: _mode != _PdfViewerMode.view,
                child: GestureDetector(
                  onTapUp: (details) {
                    if (_mode != _PdfViewerMode.view) return;
                    if (_pageWidths.isEmpty) return;

                    final selection = LinkOverlayPainter.findSelectionAt(
                      position: details.localPosition,
                      selections: list.selections,
                      pageWidths: _pageWidths,
                      pageHeights: _pageHeights,
                      scrollOffset: _scrollOffset,
                      viewSize: viewSize,
                    );

                    if (selection != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteScreen(
                            folderId: widget.folderId,
                            exerciseListId: widget.exerciseListId,
                            selectionId: selection.id,
                            noteId: selection.noteId,
                          ),
                        ),
                      );
                    }
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: LinkOverlayPainter(
                      selections: list.selections,
                      pageWidths: _pageWidths,
                      pageHeights: _pageHeights,
                      scrollOffset: _scrollOffset,
                      viewSize: viewSize,
                    ),
                  ),
                ),
              ),
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FloatingActionButton(
            heroTag: 'annotateFab',
            onPressed: _toggleAnnotateMode,
            backgroundColor: _mode == _PdfViewerMode.annotate
                ? Theme.of(context).colorScheme.secondary
                : null,
            tooltip: _mode == _PdfViewerMode.annotate
                ? 'Exit Annotate Mode'
                : 'Annotate Mode',
            child: Icon(
              _mode == _PdfViewerMode.annotate
                  ? Icons.draw
                  : Icons.draw_outlined,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'selectFab',
            onPressed: _toggleSelectMode,
            tooltip: _mode == _PdfViewerMode.select
                ? 'Exit Editing Mode'
                : 'Enter Editing Mode',
            child: Icon(
              _mode == _PdfViewerMode.select ? Icons.edit_off : Icons.edit,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      if (_mode == _PdfViewerMode.select) {
        _mode = _PdfViewerMode.view;
      } else {
        _exitAnnotateMode();
        _mode = _PdfViewerMode.select;
      }
      _selectionRect = null;
    });
  }

  void _toggleAnnotateMode() {
    setState(() {
      if (_mode == _PdfViewerMode.annotate) {
        _exitAnnotateMode();
        _mode = _PdfViewerMode.view;
      } else {
        _mode = _PdfViewerMode.annotate;
        _selectionRect = null;
        _annotationController.setActivePage(_currentPageNumber - 1);
      }
    });
  }

  void _exitAnnotateMode() {
    _annotationController.cancelStroke();
    _saveAnnotations();
  }

  void _goToAnnotatePage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _pageWidths.length) return;
    _annotationController.setActivePage(pageIndex);
    _pdfController.jumpToPage(pageIndex + 1);
    _scheduleAnnotationSave();
  }

  void _scheduleAnnotationSave() {
    _annotationSaveTimer?.cancel();
    _annotationSaveTimer = Timer(const Duration(seconds: 2), _saveAnnotations);
  }

  Future<void> _saveAnnotations() async {
    _annotationSaveTimer?.cancel();
    try {
      final folder = ref
          .read(folderProvider)
          .firstWhere((f) => f.id == widget.folderId);
      final list = folder.exerciseLists.firstWhere(
        (l) => l.id == widget.exerciseListId,
      );
      final updatedList = list.copyWith(
        annotations: _annotationController.snapshot(),
      );
      await ref
          .read(folderProvider.notifier)
          .updateExerciseList(widget.folderId, updatedList);
    } catch (e) {
      debugPrint('Error saving PDF annotations: $e');
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectionRect == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final id = const Uuid().v4();
    final noteId = const Uuid().v4();

    String? screenshotPath;
    try {
      final renderBox =
          _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final mapper = PdfCoordinateMapper(
        pageWidths: _pageWidths,
        pageHeights: _pageHeights,
        viewSize: renderBox.size,
        scrollOffset: _scrollOffset,
      );

      final document = await _pdfController.document;
      screenshotPath = await PdfScreenshotService.captureSelectionScreenshot(
        document: document,
        selectionRect: _selectionRect!,
        mapper: mapper,
        id: id,
      );
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    final renderBox2 =
        _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox2 == null) return;

    final mapper2 = PdfCoordinateMapper(
      pageWidths: _pageWidths,
      pageHeights: _pageHeights,
      viewSize: renderBox2.size,
      scrollOffset: _scrollOffset,
    );

    final actualPageIndex = mapper2.findPageIndexForY(_selectionRect!.top);
    final document2 = await _pdfController.document;
    final page = await document2.getPage(actualPageIndex + 1);
    final coords = mapper2.screenToPageRelative(
      _selectionRect!,
      actualPageIndex,
    );

    final newSelection = Selection(
      id: id,
      left: coords.left * page.width,
      top: coords.top * page.height,
      width: coords.width * page.width,
      height: coords.height * page.height,
      pageIndex: actualPageIndex,
      noteId: noteId,
      screenshotPath: screenshotPath,
    );

    await page.close();

    final folder = ref
        .read(folderProvider)
        .firstWhere((f) => f.id == widget.folderId);
    final list = folder.exerciseLists.firstWhere(
      (l) => l.id == widget.exerciseListId,
    );

    final updatedList = list.copyWith(
      selections: [...list.selections, newSelection],
    );

    final updatedLists = folder.exerciseLists
        .map((l) => l.id == list.id ? updatedList : l)
        .toList();

    await ref
        .read(folderProvider.notifier)
        .updateFolder(folder.copyWith(exerciseLists: updatedLists));

    if (!mounted) return;

    setState(() {
      _mode = _PdfViewerMode.view;
      _selectionRect = null;
      _isProcessing = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteScreen(
          folderId: widget.folderId,
          exerciseListId: widget.exerciseListId,
          selectionId: id,
          noteId: noteId,
        ),
      ),
    );
  }
}
