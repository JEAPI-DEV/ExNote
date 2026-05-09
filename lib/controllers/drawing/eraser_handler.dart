import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../../models/undo_action.dart';
import '../../models/canvas_image.dart';
import '../../utils/line_hit_test.dart';

class EraserHandler {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<CanvasImage>> canvasImagesNotifier;
  final ValueNotifier<String?> selectedImageIdNotifier;
  final void Function(UndoAction) onAction;
  final VoidCallback onContentChanged;

  final Set<SketchLine> _erasedLinesInSession = {};
  final List<int> _erasedIndicesInSession = [];
  final Set<String> _erasedImageIdsInSession = {};
  List<SketchLine>? _initialLinesInSession;

  final Map<SketchLine, Rect> _lineBoundsCache = {};

  EraserHandler({
    required this.sketchNotifier,
    required this.canvasImagesNotifier,
    required this.selectedImageIdNotifier,
    required this.onAction,
    required this.onContentChanged,
  });

  void handlePointerDown(Offset localPosition, double currentWidth) {
    _initialLinesInSession = List.from(sketchNotifier.value.lines);
    _eraseAtPosition(localPosition, currentWidth);
  }

  void handlePointerMove(Offset localPosition, double currentWidth) {
    _eraseAtPosition(localPosition, currentWidth);
  }

  void handlePointerUp() {
    if (_erasedLinesInSession.isNotEmpty) {
      onAction(
        RemoveLinesAction(
          _erasedLinesInSession.toList(),
          _erasedIndicesInSession.toList(),
        ),
      );
    } else if (_erasedImageIdsInSession.isNotEmpty) {
      onContentChanged();
    }

    _erasedLinesInSession.clear();
    _erasedIndicesInSession.clear();
    _erasedImageIdsInSession.clear();
    _initialLinesInSession = null;
  }

  void reset() {
    _erasedLinesInSession.clear();
    _erasedIndicesInSession.clear();
    _erasedImageIdsInSession.clear();
    _initialLinesInSession = null;
  }

  void _eraseAtPosition(Offset position, double currentWidth) {
    final currentSketch = sketchNotifier.value;
    final eraserRadius = currentWidth * 2;

    final linesToRemove = <SketchLine>{};

    for (final line in currentSketch.lines) {
      if (isLineHit(line, position, eraserRadius, _lineBoundsCache)) {
        linesToRemove.add(line);
      }
    }

    if (linesToRemove.isNotEmpty) {
      for (final line in linesToRemove) {
        if (!_erasedLinesInSession.contains(line)) {
          _erasedLinesInSession.add(line);
          final index =
              _initialLinesInSession?.indexOf(line) ??
              currentSketch.lines.indexOf(line);
          _erasedIndicesInSession.add(index);
        }
      }

      final newLines = currentSketch.lines
          .where((l) => !linesToRemove.contains(l))
          .toList();
      sketchNotifier.value = Sketch(lines: newLines);
    }

    final imagesToRemove = canvasImagesNotifier.value.where((image) {
      final rect = Rect.fromLTWH(
        image.left,
        image.top,
        image.width,
        image.height,
      );
      return rect.inflate(eraserRadius).contains(position);
    }).toList();

    if (imagesToRemove.isNotEmpty) {
      for (final image in imagesToRemove) {
        _erasedImageIdsInSession.add(image.id);
      }

      final removedIds = imagesToRemove.map((image) => image.id).toSet();
      canvasImagesNotifier.value = canvasImagesNotifier.value
          .where((image) => !removedIds.contains(image.id))
          .toList();

      if (removedIds.contains(selectedImageIdNotifier.value)) {
        selectedImageIdNotifier.value = null;
      }
    }
  }
}
