import 'package:flutter/widgets.dart';
import '../models/note_settings.dart';

class NoteLookLayout {
  static const Size horizontalEditPopupSize = Size(292.0, 64.0);
  static const Size verticalEditPopupSize = Size(64.0, 292.0);
  static const Size widthPresetPopupSize = Size(244.0, 86.0);
  static const double editPopupGap = 12.0;

  const NoteLookLayout._();

  static Size editPopupSize(NoteToolbarOrientation orientation) {
    return orientation == NoteToolbarOrientation.horizontal
        ? horizontalEditPopupSize
        : verticalEditPopupSize;
  }

  static Offset topLeftFromNormalized({
    required BoxConstraints constraints,
    required Size itemSize,
    required Offset normalized,
  }) {
    final maxLeft = _maxLeft(constraints, itemSize);
    final maxTop = _maxTop(constraints, itemSize);
    return Offset(
      normalized.dx.clamp(0.0, 1.0).toDouble() * maxLeft,
      normalized.dy.clamp(0.0, 1.0).toDouble() * maxTop,
    );
  }

  static Offset normalizedFromTopLeft({
    required BoxConstraints constraints,
    required Size itemSize,
    required Offset topLeft,
  }) {
    final maxLeft = _maxLeft(constraints, itemSize);
    final maxTop = _maxTop(constraints, itemSize);
    final left = topLeft.dx.clamp(0.0, maxLeft).toDouble();
    final top = topLeft.dy.clamp(0.0, maxTop).toDouble();
    return Offset(
      maxLeft == 0 ? 0 : left / maxLeft,
      maxTop == 0 ? 0 : top / maxTop,
    );
  }

  static Offset autoEditPopupTopLeft({
    required BoxConstraints constraints,
    required Size toolbarSize,
    required Offset toolbarTopLeft,
    required Size popupSize,
  }) {
    final rightLeft = toolbarTopLeft.dx + toolbarSize.width + editPopupGap;
    final hasRightSpace = rightLeft + popupSize.width <= constraints.maxWidth;
    final maxLeft = _maxLeft(constraints, popupSize);
    final maxTop = _maxTop(constraints, popupSize);
    final left = hasRightSpace
        ? rightLeft.clamp(0.0, maxLeft).toDouble()
        : (toolbarTopLeft.dx - popupSize.width - editPopupGap)
              .clamp(0.0, maxLeft)
              .toDouble();
    final top =
        (toolbarTopLeft.dy + (toolbarSize.height - popupSize.height) / 2)
            .clamp(0.0, maxTop)
            .toDouble();
    return Offset(left, top);
  }

  static Offset autoWidthPresetPopupTopLeft({
    required BoxConstraints constraints,
    required Size toolbarSize,
    required Offset toolbarTopLeft,
    required Size popupSize,
  }) {
    final maxLeft = _maxLeft(constraints, popupSize);
    final maxTop = _maxTop(constraints, popupSize);
    final left =
        (toolbarTopLeft.dx + toolbarSize.width / 2 - popupSize.width / 2)
            .clamp(0.0, maxLeft)
            .toDouble();
    final preferredTop = toolbarTopLeft.dy - popupSize.height - 12;
    final fallbackTop = toolbarTopLeft.dy + toolbarSize.height + 12;
    final top = (preferredTop >= 0 ? preferredTop : fallbackTop)
        .clamp(0.0, maxTop)
        .toDouble();
    return Offset(left, top);
  }

  static double _maxLeft(BoxConstraints constraints, Size itemSize) {
    return (constraints.maxWidth - itemSize.width)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  static double _maxTop(BoxConstraints constraints, Size itemSize) {
    return (constraints.maxHeight - itemSize.height)
        .clamp(0.0, double.infinity)
        .toDouble();
  }
}
