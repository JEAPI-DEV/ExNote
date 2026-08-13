import 'package:flutter/material.dart';

import '../controllers/pdf_annotation_controller.dart';
import '../models/drawing_tool.dart';
import 'color_swatch_button.dart';

/// Compact toolbar shown while annotating a PDF page.
///
/// Owns tool/color/width selection, undo/redo, and page navigation. It listens
/// to [PdfAnnotationController] so the active tool and undo state stay in sync.
class PdfAnnotationToolbar extends StatelessWidget {
  final PdfAnnotationController controller;
  final int pageCount;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  static const _palette = [
    Colors.redAccent,
    Colors.black,
    Colors.blueAccent,
    Colors.green,
    Colors.orangeAccent,
    Colors.purpleAccent,
  ];

  const PdfAnnotationToolbar({
    super.key,
    required this.controller,
    required this.pageCount,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
                onPressed: controller.activePageIndex > 0
                    ? onPreviousPage
                    : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              Text(
                '${controller.activePageIndex + 1} / $pageCount',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
                onPressed: controller.activePageIndex < pageCount - 1
                    ? onNextPage
                    : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              _divider(isDark),
              ValueListenableBuilder<Color>(
                valueListenable: controller.colorNotifier,
                builder: (context, color, _) {
                  return ColorSwatchButton(
                    selectedColor: color,
                    palette: _palette,
                    onPick: (picked) {
                      controller.colorNotifier.value = picked;
                      controller.toolNotifier.value = DrawingTool.pen;
                    },
                  );
                },
              ),
              _divider(isDark),
              _toolButton(context, DrawingTool.pen, Icons.edit, 'Pen'),
              _toolButton(
                context,
                DrawingTool.strokeEraser,
                Icons.delete_sweep,
                'Erase strokes',
              ),
              _divider(isDark),
              ValueListenableBuilder<double>(
                valueListenable: controller.widthNotifier,
                builder: (context, width, _) {
                  return SizedBox(
                    width: 96,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        showValueIndicator: ShowValueIndicator.onDrag,
                      ),
                      child: Slider(
                        value: width.clamp(1.0, 20.0),
                        min: 1,
                        max: 20,
                        onChanged: (value) {
                          controller.widthNotifier.value = value;
                          controller.toolNotifier.value = DrawingTool.pen;
                        },
                      ),
                    ),
                  );
                },
              ),
              _divider(isDark),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
                onPressed: controller.canUndo ? controller.undo : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo',
                onPressed: controller.canRedo ? controller.redo : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolButton(
    BuildContext context,
    DrawingTool tool,
    IconData icon,
    String tooltip,
  ) {
    return ValueListenableBuilder<DrawingTool>(
      valueListenable: controller.toolNotifier,
      builder: (context, currentTool, _) {
        final isSelected = currentTool == tool;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeColor = Theme.of(context).colorScheme.secondary;
        final inactiveColor = isDark ? Colors.white54 : Colors.black54;

        return IconButton(
          icon: Icon(icon),
          color: isSelected ? activeColor : inactiveColor,
          tooltip: tooltip,
          onPressed: () => controller.toolNotifier.value = tool,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        );
      },
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.2),
    );
  }
}
