import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onClose;

  const ChatHeader({super.key, required this.onClear, required this.onClose});

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF333333);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
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
              onPressed: onClear,
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
              icon: const Icon(Icons.close, size: 18, color: Colors.white54),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
