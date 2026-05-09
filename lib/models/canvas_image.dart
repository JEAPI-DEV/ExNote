class CanvasImage {
  final String id;
  final String path;
  final double left;
  final double top;
  final double width;
  final double height;

  const CanvasImage({
    required this.id,
    required this.path,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory CanvasImage.fromJson(Map<String, dynamic> json) => CanvasImage(
    id: json['id'] as String,
    path: json['path'] as String,
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  CanvasImage copyWith({
    String? id,
    String? path,
    double? left,
    double? top,
    double? width,
    double? height,
  }) => CanvasImage(
    id: id ?? this.id,
    path: path ?? this.path,
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
  );
}
