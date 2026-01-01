import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/grid_type.dart';

class GridPainter extends CustomPainter {
  final Matrix4 matrix;
  final GridType gridType;

  GridPainter({required this.matrix, required this.gridType});

  @override
  void paint(Canvas canvas, Size size) {
    // Compute the inverse transformation
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return;

    // The visible rect in local coordinates is 0,0 to size.width, size.height
    // Transform to world coordinates
    final topLeft = inverse.transform3(vm.Vector3(0, 0, 0));
    final bottomRight = inverse.transform3(
      vm.Vector3(size.width, size.height, 0),
    );

    final minX = topLeft.x - 1000; // margin
    final maxX = bottomRight.x + 1000;
    final minY = topLeft.y - 1000;
    final maxY = bottomRight.y + 1000;

    // Calculate current scale from matrix
    final double scale = matrix.getMaxScaleOnAxis();

    // Level of Detail (LOD) for grid
    // Base spacing is 20.0. We want to keep the visual spacing roughly constant.
    // If scale is 0.5, we want spacing to be 40.0.
    // If scale is 0.25, we want spacing to be 80.0.
    double spacing = 20.0;
    if (scale < 0.8) {
      // Find the power of 2 that brings the spacing back to a readable range
      double factor = 1.0 / scale;
      // Round to nearest power of 2 for clean grid jumps (2, 4, 8, 16...)
      double powerOfTwo = 1.0;
      while (powerOfTwo < factor * 0.5) {
        powerOfTwo *= 2;
      }
      spacing *= powerOfTwo;
    }

    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0 / scale; // Keep line width constant on screen

    if (gridType == GridType.grid) {
      // Draw grid (vertical and horizontal lines for math)
      for (
        double x = (minX / spacing).floor() * spacing;
        x <= maxX;
        x += spacing
      ) {
        canvas.drawLine(Offset(x, minY), Offset(x, maxY), paint);
      }

      for (
        double y = (minY / spacing).floor() * spacing;
        y <= maxY;
        y += spacing
      ) {
        canvas.drawLine(Offset(minX, y), Offset(maxX, y), paint);
      }
    } else {
      // Draw horizontal lines only (for writing)
      for (
        double y = (minY / spacing).floor() * spacing;
        y <= maxY;
        y += spacing
      ) {
        canvas.drawLine(Offset(minX, y), Offset(maxX, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      matrix != oldDelegate.matrix || gridType != oldDelegate.gridType;
}
