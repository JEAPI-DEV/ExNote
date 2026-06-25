import 'package:flutter/material.dart';

import 'graph_canvas_object.dart';

abstract class CanvasObject {
  const CanvasObject();

  String get id;
  String get type;
  double get left;
  double get top;
  double get width;
  double get height;

  Rect get bounds => Rect.fromLTWH(left, top, width, height);

  CanvasObject copyWithBounds({
    required double left,
    required double top,
    required double width,
    required double height,
  });

  CanvasObject moveBy(Offset delta) => copyWithBounds(
    left: left + delta.dx,
    top: top + delta.dy,
    width: width,
    height: height,
  );

  Map<String, dynamic> toJson();

  static CanvasObject fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case GraphCanvasObject.objectType:
        return GraphCanvasObject.fromJson(json);
      default:
        throw FormatException('Unsupported canvas object type: $type');
    }
  }
}
