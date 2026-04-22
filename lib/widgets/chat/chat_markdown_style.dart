import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMarkdownStyle {
  static MarkdownStyleSheet build() {
    return MarkdownStyleSheet(
      p: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      h1: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      h4: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      h5: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      h6: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
      listBullet: const TextStyle(color: Colors.white70),
      code: TextStyle(
        color: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.1),
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      blockquote: const TextStyle(
        color: Colors.white70,
        decorationColor: Colors.white24,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white24, width: 4)),
      ),
    );
  }
}
