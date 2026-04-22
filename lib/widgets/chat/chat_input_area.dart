import 'package:flutter/material.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController textController;
  final String? pendingBase64Image;
  final VoidCallback onSend;
  final VoidCallback onCaptureContext;
  final VoidCallback onRemoveImage;

  const ChatInputArea({
    super.key,
    required this.textController,
    this.pendingBase64Image,
    required this.onSend,
    required this.onCaptureContext,
    required this.onRemoveImage,
  });

  static const _borderColor = Color(0xFF333333);
  static const _accentColor = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _borderColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingBase64Image != null) _buildContextChip(_accentColor),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 20,
                    color: Colors.white54,
                  ),
                  onPressed: onCaptureContext,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: _accentColor,
                  ),
                  onPressed: onSend,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextChip(Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            'CONTEXT ATTACHED',
            style: TextStyle(
              color: accentColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemoveImage,
            child: Icon(Icons.close, size: 14, color: accentColor),
          ),
        ],
      ),
    );
  }
}
