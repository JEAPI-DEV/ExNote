import 'package:flutter/material.dart';

enum DrawingTool { pen, pixelEraser, strokeEraser }

class FastDrawingToolbar extends StatelessWidget {
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;

  const FastDrawingToolbar({
    super.key,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
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
            // Color selection
            _buildColorButton(Colors.black),
            _buildColorButton(Colors.red),
            _buildColorButton(Colors.blue),
            _buildColorButton(Colors.green),
            _buildColorButton(Colors.orange),

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
                  Icons.cleaning_services, // Standard eraser icon
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
                  Icons.delete_sweep, // Icon implying sweeping deletion
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

            // Width selection
            Expanded(
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

            // Undo/Redo
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: onUndo,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: onRedo,
              tooltip: 'Redo',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return ValueListenableBuilder<Color>(
      valueListenable: colorNotifier,
      builder: (context, selectedColor, _) {
        return ValueListenableBuilder<DrawingTool>(
          valueListenable: toolNotifier,
          builder: (context, currentTool, _) {
            final isSelected =
                currentTool == DrawingTool.pen &&
                selectedColor.value == color.value;

            return GestureDetector(
              onTap: () {
                colorNotifier.value = color;
                toolNotifier.value = DrawingTool.pen;
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
