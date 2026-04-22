import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../models/chat_message.dart';
import '../controllers/ai_chat_controller.dart';
import 'chat/chat_header.dart';
import 'chat/chat_input_area.dart';
import 'chat/chat_bubble.dart';

class AiChatDrawer extends StatefulWidget {
  final String apiKey;
  final String model;
  final bool isTutorMode;
  final bool submitLastImageOnly;
  final AiChatController chatController;
  final Future<String?> Function() onCaptureContext;
  final Function(double) onWidthChanged;

  const AiChatDrawer({
    super.key,
    required this.apiKey,
    required this.model,
    required this.isTutorMode,
    required this.submitLastImageOnly,
    required this.chatController,
    required this.onCaptureContext,
    required this.onWidthChanged,
  });

  @override
  State<AiChatDrawer> createState() => _AiChatDrawerState();
}

class _AiChatDrawerState extends State<AiChatDrawer> {
  final ScrollController _scrollController = ScrollController();
  late final AiService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = AiService(
      apiKey: widget.apiKey,
      model: widget.model,
      isTutorMode: widget.isTutorMode,
    );
    if (widget.chatController.history.isEmpty) {
      widget.chatController.history.add(
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
    final text = widget.chatController.textController.text.trim();
    final pendingImage = widget.chatController.pendingBase64Image;
    if (text.isEmpty && pendingImage == null) return;

    widget.chatController.addMessage(
      ChatMessage(text: text, isAi: false, base64Image: pendingImage),
    );
    widget.chatController.setLoading(true);

    widget.chatController.textController.clear();
    widget.chatController.setPendingImage(null);
    _scrollToBottom();

    final response = await _aiService.sendMessage(
      widget.chatController.history,
      submitLastImageOnly: widget.submitLastImageOnly,
    );

    if (mounted) {
      widget.chatController.addMessage(ChatMessage(text: response, isAi: true));
      widget.chatController.setLoading(false);
      _scrollToBottom();
    }
  }

  void _captureContext() async {
    final base64 = await widget.onCaptureContext();
    if (base64 != null) {
      widget.chatController.setPendingImage(base64);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot added as context')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
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
      onHorizontalDragUpdate: (details) {},
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
                ChatHeader(
                  onClear: () {
                    final greeting = widget.isTutorMode
                        ? "Hello! I'm your tutor. How can I help you with your notes today?"
                        : "Hello! How can I help you today?";
                    widget.chatController.clearHistory(greeting);
                  },
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
                    child: ListenableBuilder(
                      listenable: widget.chatController,
                      builder: (context, _) {
                        return ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: widget.chatController.history.length,
                          itemBuilder: (context, index) {
                            final reversedIndex =
                                widget.chatController.history.length -
                                1 -
                                index;
                            return ChatBubble(
                              message:
                                  widget.chatController.history[reversedIndex],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (widget.chatController.isLoading)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    minHeight: 1,
                  ),
                ChatInputArea(
                  textController: widget.chatController.textController,
                  pendingBase64Image: widget.chatController.pendingBase64Image,
                  onSend: _handleSend,
                  onCaptureContext: _captureContext,
                  onRemoveImage: () =>
                      widget.chatController.setPendingImage(null),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
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
