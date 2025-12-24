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
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _pdfViewKey = GlobalKey();

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
  }

  @override
  void dispose() {
    _pdfController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        backgroundColor: _isEditingMode ? Colors.red.withOpacity(0.1) : null,
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.1,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: Stack(
              key: _pdfViewKey,
              children: [
                PdfView(
                  controller: _pdfController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPageIndex = page - 1;
                    });
                  },
                  physics: _isEditingMode
                      ? const NeverScrollableScrollPhysics()
                      : null,
                ),
                // Hyperlinks
                ...list.selections
                    .where((s) => s.pageIndex == _currentPageIndex)
                    .map(
                      (s) => Positioned(
                        left: s.left + s.width - 24,
                        top: s.top,
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
                      ),
                    ),
              ],
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

    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    // Map screen coordinates to untransformed coordinates
    final untransformedLeft = (_selectionRect!.left - translation.x) / scale;
    final untransformedTop = (_selectionRect!.top - translation.y) / scale;
    final untransformedWidth = _selectionRect!.width / scale;
    final untransformedHeight = _selectionRect!.height / scale;

    // Capture screenshot
    String? screenshotPath;
    try {
      final document = await _pdfController.document;
      final page = await document.getPage(_currentPageIndex + 1);

      // Render the page at high resolution
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

          // Calculate the actual page rect in the PdfView widget (BoxFit.contain)
          final pageAspectRatio = page.width / page.height;
          final viewAspectRatio = viewSize.width / viewSize.height;

          double actualPageWidth, actualPageHeight;
          double offsetX = 0, offsetY = 0;

          if (pageAspectRatio > viewAspectRatio) {
            // Page is wider than view (relative to height)
            actualPageWidth = viewSize.width;
            actualPageHeight = viewSize.width / pageAspectRatio;
            offsetY = (viewSize.height - actualPageHeight) / 2;
          } else {
            // Page is taller than view
            actualPageHeight = viewSize.height;
            actualPageWidth = viewSize.height * pageAspectRatio;
            offsetX = (viewSize.width - actualPageWidth) / 2;
          }

          // Map untransformed coordinates to relative coordinates on the actual page
          final relativeLeft = (untransformedLeft - offsetX) / actualPageWidth;
          final relativeTop = (untransformedTop - offsetY) / actualPageHeight;
          final relativeWidth = untransformedWidth / actualPageWidth;
          final relativeHeight = untransformedHeight / actualPageHeight;

          // Map relative coordinates to pixels in the decoded image
          int cropX = (relativeLeft * decodedImage.width).toInt();
          int cropY = (relativeTop * decodedImage.height).toInt();
          int cropWidth = (relativeWidth * decodedImage.width).toInt();
          int cropHeight = (relativeHeight * decodedImage.height).toInt();

          // Clamp to image bounds
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

    final newSelection = Selection(
      id: id,
      left: untransformedLeft,
      top: untransformedTop,
      width: untransformedWidth,
      height: untransformedHeight,
      pageIndex: _currentPageIndex,
      noteId: noteId,
      screenshotPath: screenshotPath,
    );

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
