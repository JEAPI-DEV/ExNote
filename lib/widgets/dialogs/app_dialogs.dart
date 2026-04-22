import 'package:flutter/material.dart';

/// Reusable dialog helpers to reduce boilerplate across screens.
class AppDialogs {
  AppDialogs._();

  /// Shows a dialog with a single text input field.
  ///
  /// [title] - Dialog title text.
  /// [hintText] - Placeholder text for the input field.
  /// [initialText] - Pre-filled text (e.g., current name for rename).
  /// [confirmText] - Text for the confirm button.
  /// [autofocus] - Whether to auto-focus the text field.
  /// Returns the entered text, or null if cancelled.
  static Future<String?> textInput({
    required BuildContext context,
    required String title,
    required String hintText,
    String initialText = '',
    String confirmText = 'OK',
    bool autofocus = true,
  }) {
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hintText),
          autofocus: autofocus,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog with Cancel and Confirm buttons.
  ///
  /// [title] - Dialog title text.
  /// [content] - Dialog body text.
  /// [confirmText] - Text for the confirm button.
  /// [confirmColor] - Color for the confirm button text.
  /// Returns true if confirmed, false/null if cancelled.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(color: confirmColor),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }
}
