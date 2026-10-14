import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../models/chat_message.dart';
import '../services/ai/note_chat_context.dart';
import '../services/voice/reply_speech_service.dart';
import '../controllers/ai_chat_controller.dart';
import '../controllers/chat_dictation_controller.dart';
import 'chat/chat_header.dart';
import 'chat/chat_input_area.dart';
import 'chat/chat_bubble.dart';

class AiChatDrawer extends StatefulWidget {
  final String apiKey;
  final String model;
  final bool isTutorMode;
  final bool submitLastImageOnly;
  final bool readRepliesAloud;
  final ReplySpeechService? speechService;
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
    this.readRepliesAloud = false,
    this.speechService,
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
  late final ReplySpeechService _speech;
  late final ChatDictationController _dictation;
  int? _speakingReplyIndex;
  int _speechGeneration = 0;

  @override
  void initState() {
    super.initState();
    _speech = widget.speechService ?? ReplySpeechService();
    _speech.addListener(_onSpeechChanged);
    _dictation = ChatDictationController(
      widget.chatController.textController,
      beforeListen: _stopReply,
    );
    _dictation.addListener(_onDictationChanged);
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
    await _dictation.stop(discardLateResults: true);
    if (!mounted) return;
    if (!retry &&
        widget.chatController.textController.text.trim().isEmpty &&
        widget.chatController.pendingBase64Image == null) {
      return;
    }
    try {
      await _stopReply();
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
    if (widget.readRepliesAloud &&
        widget.chatController.error == null &&
        widget.chatController.history.isNotEmpty &&
        widget.chatController.history.last.isAi) {
      await _speakReply(widget.chatController.history.length - 1);
    }
  }

  void _onSpeechChanged() {
    if (mounted) setState(() {});
  }

  void _onDictationChanged() {
    final error = _dictation.error;
    if (mounted && error != null) {
      _dictation.error = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _stopReply() async {
    ++_speechGeneration;
    await _speech.stop();
    if (mounted) setState(() => _speakingReplyIndex = null);
  }

  Future<void> _speakReply(int index) async {
    final text = widget.chatController.history[index].text;
    final generation = ++_speechGeneration;
    try {
      await _dictation.stop(discardLateResults: true);
      await _speech.stop();
      if (!mounted || generation != _speechGeneration) return;
      setState(() => _speakingReplyIndex = index);
      await _speech.speak(text);
    } catch (error) {
      if (mounted && generation == _speechGeneration) {
        setState(() => _speakingReplyIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech playback failed: $error')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant AiChatDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _dictation.setEnabled(!widget.chatController.isLoading);
    if (oldWidget.readRepliesAloud && !widget.readRepliesAloud) {
      _stopReply().catchError(
        (Object error) => debugPrint('Could not stop speech: $error'),
      );
    }
  }

  @override
  void dispose() {
    ++_speechGeneration;
    _scrollController.dispose();
    _dictation.removeListener(_onDictationChanged);
    _dictation.dispose();
    _speech.removeListener(_onSpeechChanged);
    _speech.stop().catchError(
      (Object error) => debugPrint('Could not stop speech: $error'),
    );
    if (widget.speechService == null) _speech.dispose();
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
                        _stopReply().catchError(
                          (Object error) =>
                              debugPrint('Could not stop speech: $error'),
                        );
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
                                final message = widget
                                    .chatController
                                    .history[reversedIndex];
                                final speaking =
                                    reversedIndex == _speakingReplyIndex &&
                                    _speech.isSpeaking;
                                return ChatBubble(
                                  message: message,
                                  isSpeaking: speaking,
                                  onSpeak: speaking
                                      ? () => _stopReply().catchError(
                                          (Object error) => debugPrint(
                                            'Could not stop speech: $error',
                                          ),
                                        )
                                      : () => _speakReply(reversedIndex),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Full note included automatically',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                    ChatInputArea(
                      textController: widget.chatController.textController,
                      dictationController: _dictation,
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
