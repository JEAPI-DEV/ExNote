import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import 'color_swatch_button.dart';
import 'edit_selection_controls.dart';

class NoteToolbar extends StatefulWidget {
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Function(UndoAction) onAction;

  const NoteToolbar({
    super.key,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
  });

  @override
  State<NoteToolbar> createState() => _NoteToolbarState();
}

class _NoteToolbarState extends State<NoteToolbar> {
  late Color _editColor;
  late double _editWidth;
  final GlobalKey _mainColorKey = GlobalKey();

  static const _mainColors = [
    Colors.black,
    Colors.white,
    Colors.redAccent,
    Colors.blueAccent,
    Colors.green,
    Colors.blue,
    Colors.red,
    Colors.orangeAccent,
    Colors.purpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    _editColor = widget.selectionNotifier.value.isNotEmpty
        ? Color(widget.selectionNotifier.value.first.color)
        : widget.colorNotifier.value;
    _editWidth = widget.selectionNotifier.value.isNotEmpty
        ? widget.selectionNotifier.value.first.width
        : widget.widthNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final shadowColor = Colors.black.withOpacity(0.15);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ValueListenableBuilder<DrawingTool>(
        valueListenable: widget.toolNotifier,
        builder: (context, tool, _) {
          final isEditSelect = tool == DrawingTool.editSelection;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<Color>(
                valueListenable: widget.colorNotifier,
                builder: (context, selectedColor, _) {
                  return ColorSwatchButton(
                    selectedColor: selectedColor,
                    palette: _mainColors,
                    onPick: (color) {
                      widget.colorNotifier.value = color;
                      widget.toolNotifier.value = DrawingTool.pen;
                    },
                    buttonKey: _mainColorKey,
                  );
                },
              ),

              const SizedBox(width: 12),
              _buildDivider(isDark),
              const SizedBox(width: 12),

              _buildToolButton(context, DrawingTool.pen, Icons.edit, 'Pen'),
              _buildToolButton(
                context,
                DrawingTool.pixelEraser,
                Icons.cleaning_services,
                'Eraser',
              ),
              _buildToolButton(
                context,
                DrawingTool.strokeEraser,
                Icons.delete_sweep,
                'Stroke Eraser',
              ),
              _buildToolButton(
                context,
                DrawingTool.selection,
                Icons.select_all,
                'Select',
              ),
              _buildToolButton(
                context,
                DrawingTool.editSelection,
                Icons.crop_free,
                'Edit Select (lasso)',
              ),

              const SizedBox(width: 12),
              _buildDivider(isDark),
              const SizedBox(width: 12),

              SizedBox(
                width: 100,
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.widthNotifier,
                  builder: (context, width, _) => SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: width,
                      min: 1,
                      max: 20,
                      onChanged: (value) {
                        widget.widthNotifier.value = value;
                      },
                    ),
                  ),
                ),
              ),

              if (isEditSelect) ...[
                const SizedBox(width: 12),
                _buildDivider(isDark),
                const SizedBox(width: 12),
                EditSelectionControls(
                  editColor: _editColor,
                  editWidth: _editWidth,
                  onColorChanged: (color) {
                    setState(() => _editColor = color);
                    _applyStyleToSelection(color: color);
                  },
                  onWidthChanged: (value) {
                    setState(() => _editWidth = value);
                  },
                  onWidthChangeEnd: () {
                    _applyStyleToSelection(strokeWidth: _editWidth);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildToolButton(
    BuildContext context,
    DrawingTool tool,
    IconData icon,
    String tooltip,
  ) {
    return ValueListenableBuilder<DrawingTool>(
      valueListenable: widget.toolNotifier,
      builder: (context, currentTool, _) {
        final isSelected = currentTool == tool;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeColor = Theme.of(context).colorScheme.secondary;
        final inactiveColor = isDark ? Colors.white54 : Colors.black54;

        return IconButton(
          icon: Icon(icon),
          color: isSelected ? activeColor : inactiveColor,
          onPressed: () => widget.toolNotifier.value = tool,
          tooltip: tooltip,
          splashRadius: 20,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        );
      },
    );
  }

  void _applyStyleToSelection({Color? color, double? strokeWidth}) {
    final selected = widget.selectionNotifier.value;
    if (selected.isEmpty) return;

    final sketch = widget.sketchNotifier.value;
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
          color: color?.value ?? line.color,
          width: strokeWidth ?? line.width,
        );
        newLines.add(updated);
        updatedLines[i] = updated;
        indices.add(i);
      }
    }

    widget.sketchNotifier.value = Sketch(lines: updatedLines);
    widget.selectionNotifier.value = newLines;
    widget.onAction(TransformLinesAction(oldLines, newLines, indices));
  }
}
