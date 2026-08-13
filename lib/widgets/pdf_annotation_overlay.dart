import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/pdf_annotation_controller.dart';
import '../utils/pdf_page_geometry.dart';
import 'pdf_annotation_painter.dart';

/// Renders PDF annotations and, when [interactive], captures stylus input to
/// draw them.
///
/// It owns the screen-to-page coordinate mapping (via [PdfPageGeometry]) and
/// translates raw pointer events into page-point stroke commands for
/// [PdfAnnotationController].
class PdfAnnotationOverlay extends StatelessWidget {
  final PdfAnnotationController controller;
  final List<double> pageWidths;
  final List<double> pageHeights;
  final double scrollOffset;
  final Size viewSize;
  final bool interactive;
  final bool isDark;

  const PdfAnnotationOverlay({
    super.key,
    required this.controller,
    required this.pageWidths,
    required this.pageHeights,
    required this.scrollOffset,
    required this.viewSize,
    required this.interactive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (pageWidths.isEmpty) return const SizedBox.shrink();

    final geometry = PdfPageGeometry(
      viewSize: viewSize,
      pageWidths: pageWidths,
      pageHeights: pageHeights,
      scrollOffset: scrollOffset,
    );

    final painting = AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: PdfAnnotationPainter(
            annotations: controller.annotations,
            activePageIndex: controller.activePageIndex,
            activeSketch: controller.activeSketch.value,
            activeLine: controller.currentLineNotifier.value,
            activeColor: controller.colorNotifier.value,
            activeWidth: controller.widthNotifier.value,
            isDark: isDark,
            geometry: geometry,
          ),
          child: const SizedBox.expand(),
        );
      },
    );

    if (!interactive) {
      return IgnorePointer(child: painting);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: painting),
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown(geometry),
          onPointerMove: _onPointerMove(geometry),
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: const SizedBox.expand(),
        ),
      ],
    );
  }

  bool _isStylus(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus;

  void Function(PointerDownEvent) _onPointerDown(PdfPageGeometry geometry) {
    return (event) {
      if (!_isStylus(event)) return;
      final pageIndex = geometry.pageIndexAt(event.localPosition);
      if (pageIndex == null) return;
      final pagePoint = geometry.screenToPagePoint(pageIndex, event.localPosition);
      controller.beginStroke(pageIndex, pagePoint, pressure: event.pressure);
    };
  }

  void Function(PointerMoveEvent) _onPointerMove(PdfPageGeometry geometry) {
    return (event) {
      if (!_isStylus(event)) return;
      final pageIndex = controller.activePageIndex;
      if (pageIndex < 0 || pageIndex >= pageWidths.length) return;
      final pagePoint = geometry.screenToPagePoint(pageIndex, event.localPosition);
      controller.extendStroke(pagePoint);
    };
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isStylus(event)) return;
    controller.endStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_isStylus(event)) return;
    controller.cancelStroke();
  }
}
