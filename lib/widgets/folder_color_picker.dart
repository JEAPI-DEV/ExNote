import 'package:flutter/material.dart';
import '../utils/folder_colors.dart';

class FolderColorPicker extends StatelessWidget {
  final String? selectedColorHex;
  final ValueChanged<String?> onColorSelected;

  const FolderColorPicker({
    super.key,
    this.selectedColorHex,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
          child: Text(
            'Folder Color',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: FolderColors.palette.length + 1, // +1 for "no color"
            itemBuilder: (context, index) {
              if (index == 0) {
                // Default / No Color
                final isSelected = selectedColorHex == null;
                return GestureDetector(
                  onTap: () => onColorSelected(null),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).disabledColor.withOpacity(0.1),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 3,
                            )
                          : Border.all(color: Colors.grey.withOpacity(0.5)),
                    ),
                    child: const Icon(
                      Icons.block,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                );
              }

              final color = FolderColors.palette[index - 1];
              // Convert color to hex string precisely like "FF696FC7"
              final hexString = color.value.toRadixString(16).toUpperCase();
              final isSelected = selectedColorHex == hexString;

              return GestureDetector(
                onTap: () => onColorSelected(hexString),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 3,
                          )
                        : null,
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
          ),
        ),
      ],
    );
  }
}
