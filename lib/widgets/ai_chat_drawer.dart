import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/ai_service.dart';

class AiChatDrawer extends StatefulWidget {
  final String apiKey;
  final String model;
  final bool isTutorMode;
  final List<ChatMessage> history;
  final TextEditingController controller;
  final Future<String?> Function() onCaptureContext;
  final VoidCallback onClearHistory;
  final Function(double) onWidthChanged;

  const AiChatDrawer({
    super.key,
    required this.apiKey,
    required this.model,
    required this.isTutorMode,
    required this.history,
    required this.controller,
    required this.onCaptureContext,
    required this.onClearHistory,
    required this.onWidthChanged,
  });

  @override
  State<AiChatDrawer> createState() => _AiChatDrawerState();
}

class _AiChatDrawerState extends State<AiChatDrawer> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _pendingBase64Image;

  late final AiService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = AiService(
      apiKey: widget.apiKey,
      model: widget.model,
      isTutorMode: widget.isTutorMode,
    );
    if (widget.history.isEmpty) {
      widget.history.add(
        ChatMessage(
          text: widget.isTutorMode
              ? "Hello! I'm your tutor. How can I help you with your notes today?"
              : "Hello! How can I help you today?",
          isAi: true,
        ),
      );
    }
  }

  void _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty && _pendingBase64Image == null) return;

    setState(() {
      widget.history.add(
        ChatMessage(text: text, isAi: false, base64Image: _pendingBase64Image),
      );
      _isLoading = true;
    });

    final currentImage = _pendingBase64Image;
    widget.controller.clear();
    _pendingBase64Image = null;
    _scrollToBottom();

    final response = await _aiService.sendMessage(
      text,
      base64Image: currentImage,
    );

    if (mounted) {
      setState(() {
        widget.history.add(ChatMessage(text: response, isAi: true));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _captureContext() async {
    final base64 = await widget.onCaptureContext();
    if (base64 != null) {
      setState(() {
        _pendingBase64Image = base64;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot added as context')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1E1E1E);
    const borderColor = Color(0xFF333333);
    const accentColor = Color(0xFF007AFF);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: bgColor,
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.psychology_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI ASSISTANT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          widget.onClearHistory();
                          setState(() {});
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'CLEAR',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white54,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: widget.history.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(message: widget.history[index]);
                    },
                  ),
                ),

                if (_isLoading)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    minHeight: 1,
                  ),

                // Input Area
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_pendingBase64Image != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.image_outlined,
                                  size: 14,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'CONTEXT ATTACHED',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _pendingBase64Image = null,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 20,
                                  color: Colors.white54,
                                ),
                                onPressed: _captureContext,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: widget.controller,
                                maxLines: 5,
                                minLines: 1,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.send_rounded,
                                  size: 20,
                                  color: accentColor,
                                ),
                                onPressed: _handleSend,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Resize handle on the left edge
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                // Dragging left (negative delta) increases width
                // Dragging right (positive delta) decreases width
                widget.onWidthChanged(-details.delta.dx);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isAi;
  final String? base64Image;

  ChatMessage({required this.text, required this.isAi, this.base64Image});
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

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
            extensionSet:
                md.ExtensionSet(md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  LatexInlineSyntax(),
                  LatexBlockSyntax(),
                ]),
            builders: {'latex': LatexBuilder()},
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
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
              strong: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              em: const TextStyle(
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
              listBullet: const TextStyle(color: Colors.white70),
              code: TextStyle(
                color: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.1),
                fontFamily: 'monospace',
              ),
              blockquote: const TextStyle(
                color: Colors.white70,
                decorationColor: Colors.white24,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.white24, width: 4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'\\\(([\s\S]*?)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    if (match.groupCount >= 1 && match[1] != null) {
      parser.addNode(
        md.Element.text('latex', match[1]!)..attributes['display'] = 'false',
      );
      return true;
    }
    return false;
  }
}

class LatexBlockSyntax extends md.InlineSyntax {
  // Supports \[ ... \], [ ... ], and $$ ... $$
  LatexBlockSyntax() : super(r'(\\\[|\[|\$\$)([\s\S]*?)(\\\]|\]|\$\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    if (match.groupCount >= 2 && match[2] != null) {
      parser.addNode(
        md.Element.text('latex', match[2]!.trim())
          ..attributes['display'] = 'true',
      );
      return true;
    }
    return false;
  }
}

class LatexBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String text = element.textContent;
    final bool isDisplay = element.attributes['display'] == 'true';

    final mathWidget = Math.tex(
      text,
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
      textStyle:
          preferredStyle?.copyWith(color: Colors.white) ??
          const TextStyle(color: Colors.white),
      onErrorFallback: (err) =>
          Text(text, style: const TextStyle(color: Colors.redAccent)),
    );

    if (isDisplay) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: mathWidget),
      );
    }
    return mathWidget;
  }
}
