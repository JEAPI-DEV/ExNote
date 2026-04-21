import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  Future<File?> _getScreenshotFile() async {
    if (note.screenshotPath == null) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/${note.screenshotPath}');
    if (await file.exists()) return file;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FutureBuilder<File?>(
                future: _getScreenshotFile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    return Image.file(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    );
                  }
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.note, size: 40, color: Colors.grey),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      note.name ?? 'Untitled Note',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'move') onMove();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      const PopupMenuItem(value: 'move', child: Text('Move')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
