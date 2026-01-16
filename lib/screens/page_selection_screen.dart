import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PageSelectionScreen extends StatefulWidget {
  final String filePath;

  const PageSelectionScreen({super.key, required this.filePath});

  @override
  State<PageSelectionScreen> createState() => _PageSelectionScreenState();
}

class _PageSelectionScreenState extends State<PageSelectionScreen> {
  late PdfDocument _document;
  int _totalPages = 0;
  final Set<int> _selectedPages = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      _document = await PdfDocument.openFile(widget.filePath);
      setState(() {
        _totalPages = _document.pagesCount;
        // Default to all selected? Or none?
        // Usually selection starts empty or full.
        // Let's start with empty to let user pick, or full if they want to deselect.
        // User asked for "giving the user to select a range", often starts empty.
        // But "Import All" is an option.
        // Let's start empty.
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        String msg = "Failed to load PDF: $e";
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    // _document.close(); // PdfDocument.openFile returns a Future<PdfDocument>, but PdfDocument doesn't seem to implement standard close (it wraps native).
    // Wait, pdfx PdfDocument DOES have close.
    if (!_isLoading) {
      _document.close();
    }
    super.dispose();
  }

  void _togglePage(int index) {
    setState(() {
      if (_selectedPages.contains(index)) {
        _selectedPages.remove(index);
      } else {
        _selectedPages.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPages.addAll(List.generate(_totalPages, (i) => i));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAll,
            tooltip: 'Select All',
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            onPressed: _deselectAll,
            tooltip: 'Deselect All',
          ),
          TextButton(
            onPressed: _selectedPages.isEmpty
                ? null
                : () {
                    final sorted = _selectedPages.toList()..sort();
                    Navigator.pop(context, sorted);
                  },
            child: const Text('Import'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: _totalPages,
              itemBuilder: (context, index) {
                final isSelected = _selectedPages.contains(index);
                return GestureDetector(
                  onTap: () => _togglePage(index),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 3,
                                )
                              : Border.all(color: Colors.grey),
                        ),
                        child: PdfPageThumbnail(
                          document: _document,
                          pageIndex: index,
                        ),
                      ),
                      // Checkbox overlay
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                )
                              : const Icon(
                                  Icons.radio_button_unchecked,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      // Page number
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class PdfPageThumbnail extends StatefulWidget {
  final PdfDocument document;
  final int pageIndex;

  const PdfPageThumbnail({
    super.key,
    required this.document,
    required this.pageIndex,
  });

  @override
  State<PdfPageThumbnail> createState() => _PdfPageThumbnailState();
}

class _PdfPageThumbnailState extends State<PdfPageThumbnail> {
  Future<PdfPageImage?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _renderPage();
  }

  Future<PdfPageImage?> _renderPage() async {
    final page = await widget.document.getPage(widget.pageIndex + 1); // 1-based
    try {
      return await page.render(
        width: page.width, // Full resolution for better quality
        height: page.height,
        format: PdfPageImageFormat.png,
      );
    } finally {
      await page.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfPageImage?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(snapshot.data!.bytes, fit: BoxFit.contain);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
