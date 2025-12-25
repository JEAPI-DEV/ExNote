import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

class ScribbleToolbar extends StatelessWidget {
  final ScribbleNotifier notifier;

  const ScribbleToolbar({super.key, required this.notifier});

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
            ValueListenableBuilder(
              valueListenable: notifier,
              builder: (context, state, _) => IconButton(
                icon: Icon(
                  Icons.edit,
                  color: state.map(
                    drawing: (_) => Colors.blue,
                    erasing: (_) => Colors.grey.shade600,
                  ),
                ),
                onPressed: () => notifier.setColor(
                  state.map(
                    drawing: (s) => Color(s.selectedColor),
                    erasing: (_) => Colors.black,
                  ),
                ),
                tooltip: 'Pen',
              ),
            ),

            // Eraser
            ValueListenableBuilder(
              valueListenable: notifier,
              builder: (context, state, _) => IconButton(
                icon: Icon(
                  Icons.cleaning_services,
                  color: state.map(
                    drawing: (_) => Colors.grey.shade600,
                    erasing: (_) => Colors.blue,
                  ),
                ),
                onPressed: () => notifier.setEraser(),
                tooltip: 'Eraser',
              ),
            ),

            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: Colors.grey.shade300),
            const SizedBox(width: 8),

            // Width selection
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: notifier,
                builder: (context, state, _) => Slider(
                  value: state.selectedWidth,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: state.selectedWidth.round().toString(),
                  onChanged: (value) => notifier.setStrokeWidth(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, state, _) {
        final isSelected = state.map(
          drawing: (s) => s.selectedColor == color.value,
          erasing: (_) => false,
        );

        return GestureDetector(
          onTap: () => notifier.setColor(color),
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
  }
}
