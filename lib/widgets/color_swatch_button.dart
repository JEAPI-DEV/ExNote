import 'package:flutter/material.dart';

class ColorSwatchButton extends StatelessWidget {
  final Color selectedColor;
  final List<Color> palette;
  final ValueChanged<Color> onPick;
  final GlobalKey? buttonKey;

  const ColorSwatchButton({
    super.key,
    required this.selectedColor,
    required this.palette,
    required this.onPick,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      onTap: () {
        final RenderBox box =
            (buttonKey?.currentContext?.findRenderObject() ??
                    context.findRenderObject())
                as RenderBox;
        final Offset position = box.localToGlobal(Offset.zero);

        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            position.dx,
            position.dy - 120,
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
                  children: palette.map((color) {
                    final isSelected = color.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () {
                        onPick(color);
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
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
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
  }
}
