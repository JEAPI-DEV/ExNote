import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
                      onPageChanged: (page) {
                        setState(() {
                          _currentPageIndex = page - 1;
                        });
                      },
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
              // Hyperlinks
              IgnorePointer(
                ignoring: _isEditingMode,
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

    // Capture screenshot
    String? screenshotPath;
    try {
      final document = await _pdfController.document;
      final renderBox =
          _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      final viewSize = renderBox.size;
      final viewAspectRatio = viewSize.width / viewSize.height;

      // Calculate screen tops for all pages to find which pages are spanned
      List<double> pageScreenTops = [];
      List<double> pageScreenHeights = [];
      double cumTop = 0;
      for (int i = 0; i < _pageWidths.length; i++) {
        pageScreenTops.add(cumTop - _scrollOffset);
        final pageAspectRatio = _pageWidths[i] / _pageHeights[i];
        double actualPageHeight;
        if (pageAspectRatio > viewAspectRatio) {
          actualPageHeight = viewSize.width / pageAspectRatio;
        } else {
          actualPageHeight = viewSize.height;
        }
        pageScreenHeights.add(actualPageHeight);
        cumTop += actualPageHeight;
      }

      // Find start and end page indices
      int startPageIndex = -1;
      int endPageIndex = -1;

      for (int i = 0; i < pageScreenTops.length; i++) {
        final top = pageScreenTops[i];
        final bottom = top + pageScreenHeights[i];

        // Check if selection overlaps with this page
        if (_selectionRect!.bottom > top && _selectionRect!.top < bottom) {
          if (startPageIndex == -1) startPageIndex = i;
          endPageIndex = i;
        }
      }

      if (startPageIndex != -1 && endPageIndex != -1) {
        const double scaleFactor = 4.0;
        List<img.Image> renderedPages = [];
        int totalWidth = 0;
        int totalHeight = 0;

        // Render all spanned pages
        for (int i = startPageIndex; i <= endPageIndex; i++) {
          final page = await document.getPage(i + 1);
          final pageImage = await page.render(
            width: page.width * scaleFactor,
            height: page.height * scaleFactor,
            format: PdfPageImageFormat.png,
          );
          final decoded = img.decodeImage(pageImage!.bytes);
          if (decoded != null) {
            renderedPages.add(decoded);
            totalWidth = totalWidth > decoded.width
                ? totalWidth
                : decoded.width;
            totalHeight += decoded.height;
          }
          await page.close();
        }

        if (renderedPages.isNotEmpty) {
          // Stitch pages together
          final stitchedImage = img.Image(
            width: totalWidth,
            height: totalHeight,
          );
          // Fill with white in case pages have different widths
          img.fill(stitchedImage, color: img.ColorRgb8(255, 255, 255));

          int currentY = 0;
          for (var pageImg in renderedPages) {
            img.compositeImage(stitchedImage, pageImg, dstY: currentY);
            currentY += pageImg.height;
          }

          // Calculate selection relative to the start page's top
          final firstPage = await document.getPage(startPageIndex + 1);
          final firstPageAspectRatio = firstPage.width / firstPage.height;

          double actualFirstPageWidth;
          double offsetX = 0;

          if (firstPageAspectRatio > viewAspectRatio) {
            actualFirstPageWidth = viewSize.width;
          } else {
            actualFirstPageWidth = viewSize.height * firstPageAspectRatio;
            offsetX = (viewSize.width - actualFirstPageWidth) / 2;
          }

          // Selection relative to the top of the first spanned page
          final relativeLeft =
              (_selectionRect!.left - offsetX) / actualFirstPageWidth;
          final relativeTop =
              (_selectionRect!.top - pageScreenTops[startPageIndex]) /
              pageScreenHeights[startPageIndex];
          final relativeWidth = _selectionRect!.width / actualFirstPageWidth;

          // Crop coordinates on the stitched image
          int cropX = (relativeLeft * firstPage.width * scaleFactor).toInt();
          int cropY = (relativeTop * firstPage.height * scaleFactor).toInt();
          int cropWidth = (relativeWidth * firstPage.width * scaleFactor)
              .toInt();
          // For height, we need to be careful. Selection height in pixels on stitched image:
          // (Selection Height / Screen Height of Page) * PDF Height of Page * Scale
          int cropHeight =
              ((_selectionRect!.height / pageScreenHeights[startPageIndex]) *
                      firstPage.height *
                      scaleFactor)
                  .toInt();

          cropX = cropX.clamp(0, stitchedImage.width - 1);
          cropY = cropY.clamp(0, stitchedImage.height - 1);
          cropWidth = cropWidth.clamp(1, stitchedImage.width - cropX);
          cropHeight = cropHeight.clamp(1, stitchedImage.height - cropY);

          final croppedImage = img.copyCrop(
            stitchedImage,
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight,
          );

          // Add white background with padding
          const int padding = 20;
          final bgWidth = croppedImage.width + 2 * padding;
          final bgHeight = croppedImage.height + 2 * padding;
          final backgroundImage = img.Image(width: bgWidth, height: bgHeight);
          img.fill(backgroundImage, color: img.ColorRgb8(255, 255, 255));
          img.compositeImage(
            backgroundImage,
            croppedImage,
            dstX: padding,
            dstY: padding,
          );

          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/screenshot_$id.png';
          final file = File(path);
          await file.writeAsBytes(img.encodePng(backgroundImage));
          screenshotPath = path;

          await firstPage.close();
        }
      }
    } catch (e) {
      debugPrint('Error capturing multi-page screenshot: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    // Save selection metadata (using start page as reference)
    final document2 = await _pdfController.document;
    final renderBox =
        _pdfViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final viewSize = renderBox.size;
    final viewAspectRatio = viewSize.width / viewSize.height;

    int actualPageIndex = 0;
    double cumTop = 0;
    for (int i = 0; i < _pageWidths.length; i++) {
      final pageScreenTop = cumTop - _scrollOffset;
      final pageAspectRatio = _pageWidths[i] / _pageHeights[i];
      double actualPageHeight;
      if (pageAspectRatio > viewAspectRatio) {
        actualPageHeight = viewSize.width / pageAspectRatio;
      } else {
        actualPageHeight = viewSize.height;
      }
      if (_selectionRect!.top >= pageScreenTop &&
          _selectionRect!.top < pageScreenTop + actualPageHeight) {
        actualPageIndex = i;
        break;
      }
      cumTop += actualPageHeight;
    }

    final page2 = await document2.getPage(actualPageIndex + 1);
    final pageAspectRatio = page2.width / page2.height;

    double actualPageWidth, actualPageHeight;
    double offsetX = 0;

    if (pageAspectRatio > viewAspectRatio) {
      actualPageWidth = viewSize.width;
      actualPageHeight = viewSize.width / pageAspectRatio;
    } else {
      actualPageHeight = viewSize.height;
      actualPageWidth = viewSize.height * pageAspectRatio;
      offsetX = (viewSize.width - actualPageWidth) / 2;
    }

    double cumulativeTop = 0;
    for (int i = 0; i < actualPageIndex; i++) {
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
        (_selectionRect!.top - cumulativeTop + _scrollOffset) /
        actualPageHeight;
    final relativeWidth = _selectionRect!.width / actualPageWidth;
    final relativeHeight = _selectionRect!.height / actualPageHeight;

    final newSelection = Selection(
      id: id,
      left: relativeLeft * page2.width,
      top: relativeTop * page2.height,
      width: relativeWidth * page2.width,
      height: relativeHeight * page2.height,
      pageIndex: actualPageIndex,
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
