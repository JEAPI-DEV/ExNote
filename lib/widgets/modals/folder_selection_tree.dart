import 'package:flutter/material.dart';
import '../../models/folder.dart';

class FolderSelectionTree extends StatelessWidget {
  final List<Folder> allFolders;
  final bool isNoteFolder;
  final String? currentParentId;
  final String? excludeFolderId;
  final Function(String? folderId) onSelected;

  const FolderSelectionTree({
    super.key,
    required this.allFolders,
    required this.isNoteFolder,
    required this.onSelected,
    this.currentParentId,
    this.excludeFolderId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Root'),
          selected: currentParentId == null,
          onTap: () => onSelected(null),
        ),
        const Divider(),
        Expanded(
          child: ListView(shrinkWrap: true, children: _buildTree(null, 0)),
        ),
      ],
    );
  }

  List<Widget> _buildTree(String? parentId, int depth) {
    // Remove excludeFolderId from filtering to allow full hierarchy display
    final children = allFolders.where((f) {
      return f.parentId == parentId && f.isNoteFolder == isNoteFolder;
    }).toList();

    List<Widget> widgets = [];
    for (final folder in children) {
      // Check if this folder should be disabled
      final isExcluded = folder.id == excludeFolderId;
      final isEnabled = !isExcluded;

      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: ListTile(
            leading: Icon(
              folder.isNoteFolder ? Icons.folder_shared : Icons.folder,
              color: folder.colorHex != null
                  ? Color(int.parse(folder.colorHex!, radix: 16))
                  : null,
            ),
            title: Text(
              folder.name,
              style: TextStyle(
                fontWeight: currentParentId == folder.id
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isExcluded ? Colors.grey : null,
              ),
            ),
            selected: currentParentId == folder.id,
            enabled: isEnabled,
            onTap: isEnabled ? () => onSelected(folder.id) : null,
            subtitle: isExcluded
                ? const Text('Current location', style: TextStyle(fontSize: 10))
                : null,
          ),
        ),
      );
      // Always recurse to show full hierarchy, regardless of exclusion
      widgets.addAll(_buildTree(folder.id, depth + 1));
    }
    return widgets;
  }
}
