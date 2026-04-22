import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/folder_provider.dart';
import '../folder_color_picker.dart';

/// Shows a dialog to create a new folder with optional color picker.
Future<void> showCreateFolderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String hintText,
  bool isNoteFolder = false,
  String? parentId,
  String? colorHex,
}) async {
  final controller = TextEditingController();
  String? selectedColorHex = colorHex;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(hintText: hintText),
              autofocus: true,
            ),
            FolderColorPicker(
              selectedColorHex: selectedColorHex,
              onColorSelected: (hex) =>
                  setState(() => selectedColorHex = hex),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(folderProvider.notifier).addFolder(
                      controller.text,
                      isNoteFolder: isNoteFolder,
                      parentId: parentId,
                      colorHex: selectedColorHex,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}
