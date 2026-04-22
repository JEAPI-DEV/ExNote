import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import '../providers/folder_provider.dart';
import '../models/selection.dart';
import '../utils/pdf_coordinate_mapper.dart';
import '../services/pdf_screenshot_service.dart';
import '../widgets/selection_overlay.dart';
import '../widgets/link_overlay_painter.dart';
import 'note_screen.dart';

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
  bool _isEditingMode = false;
  Rect? _selectionRect;
  double _scrollOffset = 0;
  final GlobalKey _pdfViewKey = GlobalKey();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  List<double> _pageWidths = [];
  List<double> _pageHeights = [];
  bool _isProcessing = false;

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
        backgroundColor: _isEditingMode ? Colors.red.withOpacity(0.1) : null,
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
                      onPageChanged: (page) {},
                      physics: _isEditingMode
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
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
              if (_isEditingMode)
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
                        _isEditingMode = false;
                        _selectionRect = null;
                      });
                    },
                  ),
                ),
              IgnorePointer(
                ignoring: _isEditingMode,
                child: GestureDetector(
                  onTapUp: (details) {
                    if (_isEditingMode) return;
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isEditingMode = !_isEditingMode;
            _selectionRect = null;
          });
        },
        child: Icon(_isEditingMode ? Icons.edit_off : Icons.edit),
        tooltip: _isEditingMode ? 'Exit Editing Mode' : 'Enter Editing Mode',
      ),
    );
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
      _isEditingMode = false;
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
