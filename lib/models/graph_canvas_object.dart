import 'canvas_object.dart';

class GraphFunctionSpec {
  final String id;
  final String equation;
  final int color;

  const GraphFunctionSpec({
    required this.id,
    required this.equation,
    required this.color,
  });

  factory GraphFunctionSpec.fromJson(Map<String, dynamic> json) {
    return GraphFunctionSpec(
      id: json['id'] as String,
      equation: json['equation'] as String,
      color: (json['color'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'equation': equation,
    'color': color,
  };

  GraphFunctionSpec copyWith({String? id, String? equation, int? color}) {
    return GraphFunctionSpec(
      id: id ?? this.id,
      equation: equation ?? this.equation,
      color: color ?? this.color,
    );
  }
}

class GraphCanvasObject extends CanvasObject {
  static const objectType = 'graph';

  @override
  final String id;
  @override
  final double left;
  @override
  final double top;
  @override
  final double width;
  @override
  final double height;
  final String xAxisLabel;
  final String yAxisLabel;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double xTick;
  final double yTick;
  final List<GraphFunctionSpec> functions;

  const GraphCanvasObject({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.xTick,
    required this.yTick,
    required this.functions,
  });

  factory GraphCanvasObject.fromJson(Map<String, dynamic> json) {
    return GraphCanvasObject(
      id: json['id'] as String,
      left: (json['left'] as num).toDouble(),
      top: (json['top'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      xAxisLabel: json['xAxisLabel'] as String? ?? 'x',
      yAxisLabel: json['yAxisLabel'] as String? ?? 'y',
      xMin: (json['xMin'] as num?)?.toDouble() ?? -10,
      xMax: (json['xMax'] as num?)?.toDouble() ?? 10,
      yMin: (json['yMin'] as num?)?.toDouble() ?? -10,
      yMax: (json['yMax'] as num?)?.toDouble() ?? 10,
      xTick: (json['xTick'] as num?)?.toDouble() ?? 1,
      yTick: (json['yTick'] as num?)?.toDouble() ?? 1,
      functions: (json['functions'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (function) => GraphFunctionSpec.fromJson(
              (function as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  @override
  String get type => objectType;

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'xAxisLabel': xAxisLabel,
    'yAxisLabel': yAxisLabel,
    'xMin': xMin,
    'xMax': xMax,
    'yMin': yMin,
    'yMax': yMax,
    'xTick': xTick,
    'yTick': yTick,
    'functions': functions.map((function) => function.toJson()).toList(),
  };

  GraphCanvasObject copyWith({
    String? id,
    double? left,
    double? top,
    double? width,
    double? height,
    String? xAxisLabel,
    String? yAxisLabel,
    double? xMin,
    double? xMax,
    double? yMin,
    double? yMax,
    double? xTick,
    double? yTick,
    List<GraphFunctionSpec>? functions,
  }) {
    return GraphCanvasObject(
      id: id ?? this.id,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      xAxisLabel: xAxisLabel ?? this.xAxisLabel,
      yAxisLabel: yAxisLabel ?? this.yAxisLabel,
      xMin: xMin ?? this.xMin,
      xMax: xMax ?? this.xMax,
      yMin: yMin ?? this.yMin,
      yMax: yMax ?? this.yMax,
      xTick: xTick ?? this.xTick,
      yTick: yTick ?? this.yTick,
      functions: functions ?? this.functions,
    );
  }

  @override
  GraphCanvasObject copyWithBounds({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return copyWith(left: left, top: top, width: width, height: height);
  }
}
