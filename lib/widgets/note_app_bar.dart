import 'package:flutter/material.dart';

class NoteAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onExportPng;
  final VoidCallback onExportPdf;
  final VoidCallback onSave;
  final VoidCallback onSettings;
  final VoidCallback onBack;
  final VoidCallback? onDelete;
  final bool canUndo;
  final bool canRedo;
  final bool canCopy;
  final bool canPaste;

  const NoteAppBar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onCopy,
    required this.onPaste,
    required this.onExportPng,
    required this.onExportPdf,
    required this.onSave,
    required this.onSettings,
    required this.onBack,
    this.onDelete,
    this.canUndo = true,
    this.canRedo = true,
    this.canCopy = false,
    this.canPaste = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.black87;

    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 20, color: iconColor),
        onPressed: onBack,
        tooltip: 'Back',
      ),
      title: Text(
        'Note',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: iconColor,
        ),
      ),
      centerTitle: true,
      actions: [
        if (onDelete != null)
          _buildIconButton(
            Icons.delete_outline,
            onDelete!,
            'Delete',
            Colors.red,
          ),
        if (canCopy) _buildIconButton(Icons.copy, onCopy, 'Copy', iconColor),
        _buildIconButton(
          Icons.paste,
          onPaste,
          'Paste',
          canPaste ? iconColor : iconColor.withOpacity(0.3),
          enabled: canPaste,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          width: 1,
          color: iconColor.withOpacity(0.2),
        ),
        _buildIconButton(
          Icons.undo,
          onUndo,
          'Undo',
          canUndo ? iconColor : iconColor.withOpacity(0.3),
          enabled: canUndo,
        ),
        _buildIconButton(
          Icons.redo,
          onRedo,
          'Redo',
          canRedo ? iconColor : iconColor.withOpacity(0.3),
          enabled: canRedo,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          width: 1,
          color: iconColor.withOpacity(0.2),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, color: iconColor),
          tooltip: 'More',
          onSelected: (value) {
            switch (value) {
              case 'png':
                onExportPng();
                break;
              case 'pdf':
                onExportPdf();
                break;
              case 'save':
                onSave();
                break;
              case 'settings':
                onSettings();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'save',
              child: _MenuRow(Icons.save, 'Save'),
            ),
            const PopupMenuItem(
              value: 'png',
              child: _MenuRow(Icons.image, 'Export PNG'),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: _MenuRow(Icons.picture_as_pdf, 'Export PDF'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'settings',
              child: _MenuRow(Icons.settings, 'Settings'),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildIconButton(
    IconData icon,
    VoidCallback onPressed,
    String tooltip,
    Color color, {
    bool enabled = true,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      splashRadius: 20,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MenuRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
