import 'package:flutter/material.dart';
import '../models/drawing_tool.dart';

class NoteToolbar extends StatelessWidget {
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;

  const NoteToolbar({
    super.key,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
  });

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color Indicator
          _buildColorButton(context),

          const SizedBox(width: 12),
          _buildDivider(isDark),
          const SizedBox(width: 12),

          // Tools
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

          const SizedBox(width: 12),
          _buildDivider(isDark),
          const SizedBox(width: 12),

          // Width Slider (Compact)
          SizedBox(
            width: 100,
            child: ValueListenableBuilder<double>(
              valueListenable: widthNotifier,
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
                  onChanged: (value) => widthNotifier.value = value,
                ),
              ),
            ),
          ),
        ],
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
      valueListenable: toolNotifier,
      builder: (context, currentTool, _) {
        final isSelected = currentTool == tool;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeColor = Theme.of(context).colorScheme.secondary;
        final inactiveColor = isDark ? Colors.white54 : Colors.black54;

        return IconButton(
          icon: Icon(icon),
          color: isSelected ? activeColor : inactiveColor,
          onPressed: () => toolNotifier.value = tool,
          tooltip: tooltip,
          splashRadius: 20,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        );
      },
    );
  }

  Widget _buildColorButton(BuildContext context) {
    final colors = [
      Colors.black,
      Colors.white, // For dark mode
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
    ];

    return ValueListenableBuilder<Color>(
      valueListenable: colorNotifier,
      builder: (context, selectedColor, _) {
        return GestureDetector(
          onTap: () {
            // Show popup
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset position = box.localToGlobal(Offset.zero);

            showMenu(
              context: context,
              position: RelativeRect.fromLTRB(
                position.dx,
                position.dy - 120, // Show above
                position.dx + 50,
                position.dy,
              ),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              items: [
                PopupMenuItem(
                  enabled: false,
                  child: SizedBox(
                    width: 160,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((color) {
                        final isSelected = color.value == selectedColor.value;
                        return GestureDetector(
                          onTap: () {
                            colorNotifier.value = color;
                            toolNotifier.value = DrawingTool.pen;
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selectedColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
