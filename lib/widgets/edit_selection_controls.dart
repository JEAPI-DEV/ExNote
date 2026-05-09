import 'package:flutter/material.dart';
import 'color_swatch_button.dart';

class EditSelectionControls extends StatelessWidget {
  final Color editColor;
  final double editWidth;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onWidthChangeEnd;

  const EditSelectionControls({
    super.key,
    required this.editColor,
    required this.editWidth,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onWidthChangeEnd,
  });

  static const _colors = [
    Colors.black,
    Colors.white,
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorSwatchButton(
              selectedColor: editColor,
              palette: _colors,
              onPick: onColorChanged,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
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
                  value: editWidth,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: editWidth.round().toString(),
                  onChanged: onWidthChanged,
                  onChangeEnd: (_) => onWidthChangeEnd(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
