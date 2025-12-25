import 'dart:ui';
import 'package:flutter/material.dart';

class ExerciseSelectionOverlay extends StatefulWidget {
  final Rect? rect;
  final Function(Rect?) onRectChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ExerciseSelectionOverlay({
    super.key,
    required this.rect,
    required this.onRectChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ExerciseSelectionOverlay> createState() =>
      _ExerciseSelectionOverlayState();
}

class _ExerciseSelectionOverlayState extends State<ExerciseSelectionOverlay> {
  _HandleType? _activeHandle;
  Offset? _initialFingerGlobal;
  Offset? _initialHandlePosition;

  @override
  Widget build(BuildContext context) {
    debugPrint('Building ExerciseSelectionOverlay, rect: $widget.rect');
    return Stack(
      children: [
        // Dimmed background
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5))),
        // Stylus gesture detector for drawing the initial rect or clearing it
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (details) {
              debugPrint(
                'Pan start: ${details.kind} at ${details.localPosition}',
              );
              if (details.kind == PointerDeviceKind.stylus &&
                  _activeHandle == null) {
                widget.onRectChanged(
                  Rect.fromLTWH(
                    details.localPosition.dx,
                    details.localPosition.dy,
                    0,
                    0,
                  ),
                );
              }
            },
            onPanUpdate: (details) {
              debugPrint(
                'Pan update: ${details.kind} at ${details.localPosition}',
              );
              if (details.kind == PointerDeviceKind.stylus &&
                  _activeHandle == null &&
                  widget.rect != null) {
                widget.onRectChanged(
                  Rect.fromPoints(widget.rect!.topLeft, details.localPosition),
                );
              }
            },
            onTap: () {
              debugPrint('Tap detected');
              if (_activeHandle == null) {
                widget.onRectChanged(null);
              }
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        if (widget.rect != null) ...[
          // Clear selection area
          Positioned.fromRect(
            rect: widget.rect!,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                color: Colors.blue.withOpacity(0.05),
              ),
            ),
          ),
          // Handles
          _buildHandle(widget.rect!.topLeft, _HandleType.topLeft),
          _buildHandle(widget.rect!.topRight, _HandleType.topRight),
          _buildHandle(widget.rect!.bottomLeft, _HandleType.bottomLeft),
          _buildHandle(widget.rect!.bottomRight, _HandleType.bottomRight),
        ],
        // OK/Cancel buttons
        Positioned(
          top: 40,
          right: 20,
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                label: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.rect != null ? widget.onConfirm : null,
                icon: const Icon(Icons.check, color: Colors.white, size: 20),
                label: const Text('OK', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandle(Offset position, _HandleType type) {
    return Positioned(
      left: position.dx - 20,
      top: position.dy - 20,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          if (details.kind == PointerDeviceKind.stylus) {
            _activeHandle = type;
            _initialFingerGlobal = details.globalPosition;
            _initialHandlePosition = position;
          }
        },
        onPanUpdate: (details) {
          if (details.kind == PointerDeviceKind.stylus &&
              _activeHandle == type &&
              _initialFingerGlobal != null &&
              _initialHandlePosition != null) {
            final delta = details.globalPosition - _initialFingerGlobal!;
            _updateRect(_initialHandlePosition! + delta, type);
          }
        },
        onPanEnd: (_) {
          _activeHandle = null;
          _initialFingerGlobal = null;
          _initialHandlePosition = null;
        },
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateRect(Offset globalPosition, _HandleType type) {
    if (widget.rect == null) return;

    Rect newRect;
    switch (type) {
      case _HandleType.topLeft:
        newRect = Rect.fromLTRB(
          globalPosition.dx,
          globalPosition.dy,
          widget.rect!.right,
          widget.rect!.bottom,
        );
        break;
      case _HandleType.topRight:
        newRect = Rect.fromLTRB(
          widget.rect!.left,
          globalPosition.dy,
          globalPosition.dx,
          widget.rect!.bottom,
        );
        break;
      case _HandleType.bottomLeft:
        newRect = Rect.fromLTRB(
          globalPosition.dx,
          widget.rect!.top,
          widget.rect!.right,
          globalPosition.dy,
        );
        break;
      case _HandleType.bottomRight:
        newRect = Rect.fromLTRB(
          widget.rect!.left,
          widget.rect!.top,
          globalPosition.dx,
          globalPosition.dy,
        );
        break;
    }
    widget.onRectChanged(newRect);
  }
}

enum _HandleType { topLeft, topRight, bottomLeft, bottomRight }
