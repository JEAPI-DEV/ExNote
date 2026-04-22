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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildColorOption(
                  context: context,
                  color: null,
                  isSelected: selectedColorHex == null,
                  onSelect: () => onColorSelected(null),
                ),
                ...FolderColors.palette.map((color) {
                  final hexString = color.value.toRadixString(16).toUpperCase();
                  return _buildColorOption(
                    context: context,
                    color: color,
                    isSelected: selectedColorHex == hexString,
                    onSelect: () => onColorSelected(hexString),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorOption({
    required BuildContext context,
    required Color? color,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Theme.of(context).disabledColor.withOpacity(0.1),
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 3)
              : Border.all(color: Colors.grey.withOpacity(0.5)),
          boxShadow: color != null
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: color == null
            ? const Icon(Icons.block, size: 20, color: Colors.grey)
            : null,
      ),
    );
  }
}
