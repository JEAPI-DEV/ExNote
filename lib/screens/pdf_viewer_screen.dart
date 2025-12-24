import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../providers/folder_provider.dart';
import '../models/selection.dart';
import '../widgets/selection_overlay.dart';
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
  int _currentPageIndex = 0;
  double _scrollOffset = 0;
  final GlobalKey _pdfViewKey = GlobalKey();
  List<double> _pageWidths = [];
  List<double> _pageHeights = [];

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

    return Scaffold(
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
                child: PdfView(
                  key: _pdfViewKey,
                  controller: _pdfController,
                  scrollDirection: Axis.vertical,
                  pageSnapping: false,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPageIndex = page - 1;
                    });
                  },
                  physics: _isEditingMode
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                ),
              ),
              // Hyperlinks
              IgnorePointer(
                ignoring: false,
                child: Stack(
                  children: list.selections.map((s) {
                    if (s.pageIndex >= _pageWidths.length ||
                        s.pageIndex >= _pageHeights.length) {
                      return const SizedBox.shrink();
                    }
                    final viewAspectRatio = viewSize.width / viewSize.height;
                    final pageWidth = _pageWidths[s.pageIndex];
                    final pageHeight = _pageHeights[s.pageIndex];
                    final pageAspectRatio = pageWidth / pageHeight;

                    double actualPageWidth, actualPageHeight;
                    double offsetX = 0, offsetY = 0;
                    if (pageAspectRatio > viewAspectRatio) {
                      actualPageWidth = viewSize.width;
                      actualPageHeight = viewSize.width / pageAspectRatio;
                      offsetY = 0; // Pages are not centered vertically
                    } else {
                      actualPageHeight = viewSize.height;
                      actualPageWidth = viewSize.height * pageAspectRatio;
                      offsetX = (viewSize.width - actualPageWidth) / 2;
                      offsetY = 0;
                    }

                    double cumulativeTop = 0;
                    for (int i = 0; i < s.pageIndex; i++) {
                      final prevPageAspectRatio =
                          _pageWidths[i] / _pageHeights[i];
                      double prevActualPageHeight;
                      if (prevPageAspectRatio > viewAspectRatio) {
                        prevActualPageHeight =
                            viewSize.width / prevPageAspectRatio;
                      } else {
                        prevActualPageHeight = viewSize.height;
                      }
                      cumulativeTop += prevActualPageHeight;
                    }

                    final screenLeft =
                        offsetX + (s.left / pageWidth) * actualPageWidth;
                    final screenTop =
                        cumulativeTop +
                        offsetY +
                        (s.top / pageHeight) * actualPageHeight -
                        _scrollOffset;
                    final screenWidth = (s.width / pageWidth) * actualPageWidth;

                    // Only show if roughly within viewport
                    if (screenTop < -100 || screenTop > viewSize.height + 100) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      left: screenLeft + screenWidth - 24,
                      top: screenTop,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NoteScreen(
                              folderId: widget.folderId,
                              exerciseListId: widget.exerciseListId,
                              selectionId: s.id,
                              noteId: s.noteId,
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.link,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
    if (_selectionRect == null) return;

    final id = const Uuid().v4();
    final noteId = const Uuid().v4();

    // Capture screenshot
    String? screenshotPath;
    try {
      final document = await _pdfController.document;
      final page = await document.getPage(_currentPageIndex + 1);

      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );

      if (pageImage != null) {
        final decodedImage = img.decodeImage(pageImage.bytes);

        if (decodedImage != null) {
          final renderBox =
              _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          final viewSize = renderBox.size;

          final pageAspectRatio = page.width / page.height;
          final viewAspectRatio = viewSize.width / viewSize.height;

          double actualPageWidth, actualPageHeight;
          double offsetX = 0, offsetY = 0;

          if (pageAspectRatio > viewAspectRatio) {
            actualPageWidth = viewSize.width;
            actualPageHeight = viewSize.width / pageAspectRatio;
            offsetY = 0; // Pages are not centered vertically in vertical scroll
          } else {
            actualPageHeight = viewSize.height;
            actualPageWidth = viewSize.height * pageAspectRatio;
            offsetX = (viewSize.width - actualPageWidth) / 2;
            offsetY = 0;
          }

          double cumulativeTop = 0;
          for (int i = 0; i < _currentPageIndex; i++) {
            final prevPageAspectRatio = _pageWidths[i] / _pageHeights[i];
            double prevActualPageHeight;
            if (prevPageAspectRatio > viewAspectRatio) {
              prevActualPageHeight = viewSize.width / prevPageAspectRatio;
            } else {
              prevActualPageHeight = viewSize.height;
            }
            cumulativeTop += prevActualPageHeight;
          }

          final relativeLeft =
              (_selectionRect!.left - offsetX) / actualPageWidth;
          final relativeTop =
              (_selectionRect!.top - cumulativeTop + _scrollOffset - offsetY) /
              actualPageHeight;
          final relativeWidth = _selectionRect!.width / actualPageWidth;
          final relativeHeight = _selectionRect!.height / actualPageHeight;

          int cropX = (relativeLeft * decodedImage.width).toInt();
          int cropY = (relativeTop * decodedImage.height).toInt();
          int cropWidth = (relativeWidth * decodedImage.width).toInt();
          int cropHeight = (relativeHeight * decodedImage.height).toInt();

          cropX = cropX.clamp(0, decodedImage.width - 1);
          cropY = cropY.clamp(0, decodedImage.height - 1);
          cropWidth = cropWidth.clamp(1, decodedImage.width - cropX);
          cropHeight = cropHeight.clamp(1, decodedImage.height - cropY);

          final croppedImage = img.copyCrop(
            decodedImage,
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight,
          );

          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/screenshot_$id.png';
          final file = File(path);
          await file.writeAsBytes(img.encodePng(croppedImage));
          screenshotPath = path;
        }
      }

      await page.close();
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
    }

    // We save the coordinates in page coordinate system
    final document2 = await _pdfController.document;
    final page2 = await document2.getPage(_currentPageIndex + 1);
    final renderBox =
        _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final viewSize = renderBox.size;

    final pageAspectRatio = page2.width / page2.height;
    final viewAspectRatio = viewSize.width / viewSize.height;

    double actualPageWidth, actualPageHeight;
    double offsetX = 0, offsetY = 0;

    if (pageAspectRatio > viewAspectRatio) {
      actualPageWidth = viewSize.width;
      actualPageHeight = viewSize.width / pageAspectRatio;
      offsetY = 0; // Pages are not centered vertically
    } else {
      actualPageHeight = viewSize.height;
      actualPageWidth = viewSize.height * pageAspectRatio;
      offsetX = (viewSize.width - actualPageWidth) / 2;
      offsetY = 0;
    }

    double cumulativeTop = 0;
    for (int i = 0; i < _currentPageIndex; i++) {
      final prevPageAspectRatio = _pageWidths[i] / _pageHeights[i];
      double prevActualPageHeight;
      if (prevPageAspectRatio > viewAspectRatio) {
        prevActualPageHeight = viewSize.width / prevPageAspectRatio;
      } else {
        prevActualPageHeight = viewSize.height;
      }
      cumulativeTop += prevActualPageHeight;
    }

    final relativeLeft = (_selectionRect!.left - offsetX) / actualPageWidth;
    final relativeTop =
        (_selectionRect!.top - cumulativeTop + _scrollOffset - offsetY) /
        actualPageHeight;
    final relativeWidth = _selectionRect!.width / actualPageWidth;
    final relativeHeight = _selectionRect!.height / actualPageHeight;

    final newSelection = Selection(
      id: id,
      left: relativeLeft * page2.width,
      top: relativeTop * page2.height,
      width: relativeWidth * page2.width,
      height: relativeHeight * page2.height,
      pageIndex: _currentPageIndex,
      noteId: noteId,
      screenshotPath: screenshotPath,
    );

    await page2.close();

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
