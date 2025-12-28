import 'package:flutter/material.dart';

enum DrawingTool { pen, pixelEraser, strokeEraser }

class FastDrawingToolbar extends StatelessWidget {
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;

  const FastDrawingToolbar({
    super.key,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Color Popup
            _buildColorPopup(),

            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: Colors.grey.shade300),
            const SizedBox(width: 8),

            // Pen tool
            ValueListenableBuilder<DrawingTool>(
              valueListenable: toolNotifier,
              builder: (context, currentTool, _) => IconButton(
                icon: Icon(
                  Icons.edit,
                  color: currentTool == DrawingTool.pen
                      ? Colors.blue
                      : Colors.grey.shade600,
                ),
                onPressed: () => toolNotifier.value = DrawingTool.pen,
                tooltip: 'Pen',
              ),
            ),

            // Pixel Eraser
            ValueListenableBuilder<DrawingTool>(
              valueListenable: toolNotifier,
              builder: (context, currentTool, _) => IconButton(
                icon: Icon(
                  Icons.cleaning_services,
                  color: currentTool == DrawingTool.pixelEraser
                      ? Colors.blue
                      : Colors.grey.shade600,
                ),
                onPressed: () => toolNotifier.value = DrawingTool.pixelEraser,
                tooltip: 'Pixel Eraser (Standard)',
              ),
            ),

            // Stroke Eraser
            ValueListenableBuilder<DrawingTool>(
              valueListenable: toolNotifier,
              builder: (context, currentTool, _) => IconButton(
                icon: Icon(
                  Icons.delete_sweep,
                  color: currentTool == DrawingTool.strokeEraser
                      ? Colors.blue
                      : Colors.grey.shade600,
                ),
                onPressed: () => toolNotifier.value = DrawingTool.strokeEraser,
                tooltip: 'Stroke Eraser (Delete Whole)',
              ),
            ),

            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: Colors.grey.shade300),
            const SizedBox(width: 8),

            // Compact Width selection
            SizedBox(
              width: 150,
              child: ValueListenableBuilder<double>(
                valueListenable: widthNotifier,
                builder: (context, width, _) => Slider(
                  value: width,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: width.round().toString(),
                  onChanged: (value) => widthNotifier.value = value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPopup() {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.teal,
    ];

    return ValueListenableBuilder<Color>(
      valueListenable: colorNotifier,
      builder: (context, selectedColor, _) {
        return PopupMenuButton<Color>(
          tooltip: 'Select Color',
          initialValue: selectedColor,
          onSelected: (color) {
            colorNotifier.value = color;
            toolNotifier.value = DrawingTool.pen;
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                enabled: false,
                child: SizedBox(
                  width: 200,
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ];
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selectedColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
          ),
        );
      },
    );
  }
}
