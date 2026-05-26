import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import '../utils/sketch_bounds.dart';
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
  final GlobalKey _widthPresetButtonKey = GlobalKey();
  final List<double> _widthPresets = [..._defaultWidthPresets];
  Timer? _presetHoldTimer;
  OverlayEntry? _widthPresetOverlay;
  int? _editingWidthPresetIndex;
  double _editingWidthPresetValue = 1;
  bool _presetHoldCompleted = false;

  static const _widthPresetPrefsKey = 'strokeWidthPresets';
  static const _defaultWidthPresets = [2.0, 6.0, 12.0];

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
    _loadWidthPresets();
  }

  @override
  void dispose() {
    _presetHoldTimer?.cancel();
    _hideWidthPresetOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final shadowColor = Colors.black.withValues(alpha: 0.15);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

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
              _buildWidthPresetButton(context),
              const SizedBox(width: 4),

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
                      showValueIndicator: ShowValueIndicator.onDrag,
                    ),
                    child: Slider(
                      value: width,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: width.round().toString(),
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
                  onMirrorX: () => _mirrorSelection(mirrorOverXAxis: true),
                  onMirrorY: () => _mirrorSelection(mirrorOverXAxis: false),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildWidthPresetButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white54 : Colors.black54;

    return IconButton(
      key: _widthPresetButtonKey,
      icon: Icon(Icons.more_vert, color: iconColor, size: 20),
      onPressed: () => _toggleWidthPresetOverlay(context),
      tooltip: 'Stroke width presets',
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
    );
  }

  Future<void> _loadWidthPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_widthPresetPrefsKey);
    if (saved == null || saved.length != _defaultWidthPresets.length) return;

    final loaded = saved
        .map(double.tryParse)
        .whereType<double>()
        .map(_clampStrokeWidth)
        .toList();
    if (loaded.length != _defaultWidthPresets.length || !mounted) return;

    setState(() {
      for (int i = 0; i < _widthPresets.length; i++) {
        _widthPresets[i] = loaded[i];
      }
    });
  }

  Future<void> _saveWidthPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _widthPresetPrefsKey,
      _widthPresets.map((width) => width.round().toString()).toList(),
    );
  }

  double _clampStrokeWidth(double width) => width.clamp(1.0, 20.0);

  void _toggleWidthPresetOverlay(BuildContext context) {
    if (_widthPresetOverlay != null) {
      _hideWidthPresetOverlay();
      return;
    }

    _showWidthPresetOverlay(context);
  }

  void _showWidthPresetOverlay(BuildContext context) {
    final buttonContext = _widthPresetButtonKey.currentContext;
    final overlay = Overlay.of(context);
    if (buttonContext == null) return;

    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonSize = buttonBox.size;
    const popupWidth = 244.0;
    const popupHeight = 86.0;
    const editorHeight = 104.0;
    final popupLeft = (buttonTopLeft.dx + buttonSize.width / 2 - popupWidth / 2)
        .clamp(8.0, overlayBox.size.width - popupWidth - 8.0);
    final popupTop = (buttonTopLeft.dy - popupHeight - 12).clamp(
      8.0,
      overlayBox.size.height - popupHeight - 8.0,
    );
    final editorTop = (popupTop - editorHeight - 8).clamp(
      8.0,
      overlayBox.size.height - editorHeight - 8.0,
    );

    _editingWidthPresetIndex = null;
    _widthPresetOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideWidthPresetOverlay,
              ),
            ),
            if (_editingWidthPresetIndex != null)
              Positioned(
                left: popupLeft,
                top: editorTop,
                width: popupWidth,
                child: Material(
                  color: Colors.transparent,
                  child: _buildWidthPresetEditor(context),
                ),
              ),
            Positioned(
              left: popupLeft,
              top: popupTop,
              width: popupWidth,
              child: Material(
                color: Colors.transparent,
                child: _buildWidthPresetPopup(context),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_widthPresetOverlay!);
  }

  void _hideWidthPresetOverlay() {
    _presetHoldTimer?.cancel();
    _widthPresetOverlay?.remove();
    _widthPresetOverlay = null;
    _editingWidthPresetIndex = null;
  }

  void _rebuildWidthPresetOverlay() {
    if (mounted) setState(() {});
    _widthPresetOverlay?.markNeedsBuild();
  }

  Widget _buildWidthPresetPopup(BuildContext context) {
    return _buildFloatingPresetBox(
      context,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < _widthPresets.length; i++)
            _buildWidthPresetTile(context, i),
        ],
      ),
    );
  }

  Widget _buildWidthPresetTile(BuildContext context, int index) {
    final preset = _widthPresets[index].round();
    final selected = widget.widthNotifier.value.round() == preset;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _startPresetHold(index),
      onTapUp: (_) {
        _presetHoldTimer?.cancel();
        if (!_presetHoldCompleted) _selectWidthPreset(index);
      },
      onTapCancel: () => _presetHoldTimer?.cancel(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 64,
        height: 58,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.secondary.withValues(alpha: 0.16)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colorScheme.secondary
                : colorScheme.outline.withValues(alpha: 0.24),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            preset.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? colorScheme.secondary : null,
            ),
          ),
        ),
      ),
    );
  }

  void _startPresetHold(int index) {
    _presetHoldTimer?.cancel();
    _presetHoldCompleted = false;
    _presetHoldTimer = Timer(const Duration(seconds: 3), () {
      _presetHoldCompleted = true;
      _editingWidthPresetIndex = index;
      _editingWidthPresetValue = _widthPresets[index];
      _rebuildWidthPresetOverlay();
    });
  }

  void _selectWidthPreset(int index) {
    widget.widthNotifier.value = _widthPresets[index].roundToDouble();
    _editingWidthPresetIndex = null;
    _rebuildWidthPresetOverlay();
  }

  Widget _buildWidthPresetEditor(BuildContext context) {
    final index = _editingWidthPresetIndex;
    if (index == null) return const SizedBox.shrink();

    return _buildFloatingPresetBox(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set preset ${index + 1}: ${_editingWidthPresetValue.round()}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              showValueIndicator: ShowValueIndicator.onDrag,
            ),
            child: Slider(
              value: _editingWidthPresetValue,
              min: 1,
              max: 20,
              divisions: 19,
              label: _editingWidthPresetValue.round().toString(),
              onChanged: (value) {
                _editingWidthPresetValue = value;
                _rebuildWidthPresetOverlay();
              },
              onChangeEnd: (value) {
                _widthPresets[index] = value.roundToDouble();
                _saveWidthPresets();
                _rebuildWidthPresetOverlay();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPresetBox(
    BuildContext context, {
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.2),
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
          color: color?.toARGB32() ?? line.color,
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

  void _mirrorSelection({required bool mirrorOverXAxis}) {
    final selected = widget.selectionNotifier.value;
    if (selected.isEmpty) return;

    final bounds = computeLineBounds(selected);
    if (bounds == Rect.zero) return;

    final sketch = widget.sketchNotifier.value;
    final selectedSet = selected.toSet();
    final updatedLines = [...sketch.lines];
    final oldLines = <SketchLine>[];
    final newLines = <SketchLine>[];
    final indices = <int>[];

    for (int i = 0; i < sketch.lines.length; i++) {
      final line = sketch.lines[i];
      if (!selectedSet.contains(line)) continue;

      oldLines.add(line);
      final updated = line.copyWith(
        points: line.points.map((p) {
          if (mirrorOverXAxis) {
            return Point(
              p.x,
              bounds.center.dy - (p.y - bounds.center.dy),
              pressure: p.pressure,
            );
          }

          return Point(
            bounds.center.dx - (p.x - bounds.center.dx),
            p.y,
            pressure: p.pressure,
          );
        }).toList(),
      );
      newLines.add(updated);
      updatedLines[i] = updated;
      indices.add(i);
    }

    if (newLines.isEmpty) return;

    widget.sketchNotifier.value = Sketch(lines: updatedLines);
    widget.selectionNotifier.value = newLines;
    widget.onAction(TransformLinesAction(oldLines, newLines, indices));
  }
}
