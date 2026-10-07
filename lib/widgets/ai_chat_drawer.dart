import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../models/chat_message.dart';
import '../services/ai/note_chat_context.dart';
import '../services/voice/reply_speech_service.dart';
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
  final VoidCallback onClose;
  final Future<String?> Function() onCaptureContext;
  final Function(double) onWidthChanged;
  final Future<NoteChatContext> Function(String query) onNoteContext;

  const AiChatDrawer({
    super.key,
    required this.apiKey,
    required this.model,
    required this.isTutorMode,
    required this.submitLastImageOnly,
    required this.chatController,
    required this.onClose,
    required this.onCaptureContext,
    required this.onWidthChanged,
    required this.onNoteContext,
  });

  @override
  State<AiChatDrawer> createState() => _AiChatDrawerState();
}

class _AiChatDrawerState extends State<AiChatDrawer> {
  final ScrollController _scrollController = ScrollController();
  final ReplySpeechService _speech = ReplySpeechService();

  @override
  void initState() {
    super.initState();
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

  Future<void> _handleSend({bool retry = false}) async {
    if (widget.chatController.isLoading) return;
    if (!retry &&
        widget.chatController.textController.text.trim().isEmpty &&
        widget.chatController.pendingBase64Image == null) {
      return;
    }
    try {
      await _speech.stop();
    } catch (error) {
      debugPrint('Could not stop speech playback: $error');
    }
    if (!mounted || widget.chatController.isLoading) return;
    await widget.chatController.send(
      service: AiService(
        apiKey: widget.apiKey,
        model: widget.model,
        isTutorMode: widget.isTutorMode,
      ),
      context: widget.onNoteContext,
      submitLastImageOnly: widget.submitLastImageOnly,
      retry: retry,
    );
    if (!mounted) return;
    _scrollToBottom();
    if (widget.chatController.readReplies &&
        widget.chatController.error == null &&
        widget.chatController.history.isNotEmpty &&
        widget.chatController.history.last.isAi) {
      try {
        await _speech.speak(widget.chatController.history.last.text);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech playback failed: $error')),
          );
        }
      }
    }
  }

  Future<void> _speakReply(String text) async {
    try {
      await _speech.speak(text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech playback failed: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _captureContext() async {
    final base64 = await widget.onCaptureContext();
    if (base64 != null && mounted) {
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

    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.chatController,
        builder: (context, _) => GestureDetector(
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
                        if (widget.chatController.isLoading) return;
                        final greeting = widget.isTutorMode
                            ? "Hello! I'm your tutor. How can I help you with your notes today?"
                            : "Hello! How can I help you today?";
                        widget.chatController.clearHistory(greeting);
                      },
                      onClose: widget.onClose,
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
                                  onSpeak: () => _speakReply(
                                    widget
                                        .chatController
                                        .history[reversedIndex]
                                        .text,
                                  ),
                                  message: widget
                                      .chatController
                                      .history[reversedIndex],
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
                    if (widget.chatController.error != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.chatController.error!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.chatController.isLoading
                                  ? null
                                  : () => _handleSend(retry: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    SwitchListTile(
                      dense: true,
                      title: const Text(
                        'Read replies aloud',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: widget.chatController.readReplies,
                      onChanged: (value) {
                        widget.chatController.setReadReplies(value);
                        if (!value) _speech.stop();
                      },
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      onPressed: _speech.stop,
                      icon: const Icon(Icons.volume_off_outlined, size: 16),
                      label: const Text('Stop reading'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Full note included automatically',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                    ChatInputArea(
                      textController: widget.chatController.textController,
                      pendingBase64Image:
                          widget.chatController.pendingBase64Image,
                      isLoading: widget.chatController.isLoading,
                      onSend: () => _handleSend(),
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
        ),
      ),
    );
  }
}
