import 'dart:convert';
import 'package:exnote/services/llm_parser/latex_block_syntax.dart';
import 'package:exnote/services/llm_parser/latex_element_builder.dart';
import 'package:exnote/services/llm_parser/latex_inline_syntax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../models/chat_message.dart';
import 'chat_markdown_style.dart' show ChatMarkdownStyle;

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isAi = message.isAi;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isAi ? 'AI' : 'YOU',
                style: TextStyle(
                  color: isAi ? const Color(0xFF007AFF) : Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (message.base64Image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  base64Decode(message.base64Image!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          MarkdownBody(
            data: message.text,
            selectable: true,
            builders: {
              'latex': LatexElementBuilder(
                textStyle: const TextStyle(color: Colors.white),
              ),
            },
            extensionSet: md.ExtensionSet(
              [LatexBlockSyntax()],
              [LatexInlineSyntax(), md.InlineHtmlSyntax()],
            ),
            styleSheet: ChatMarkdownStyle.build(),
          ),
        ],
      ),
    );
  }
}
