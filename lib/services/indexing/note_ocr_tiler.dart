import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class NoteOcrRegion {
  final int number;
  final Uint8List png;
  final List<double> bounds;
  final int expectedLines;
  const NoteOcrRegion({
    required this.number,
    required this.png,
    required this.bounds,
    required this.expectedLines,
  });
}

/// Finds ink bands and produces square, legible inputs for Gemma's vision encoder.
/// Page images for chat/export remain unchanged.
class NoteOcrTiler {
  Future<List<NoteOcrRegion>> split(Uint8List png) =>
      Isolate.run(() => _split(png));

  static List<NoteOcrRegion> _split(Uint8List png) {
    final image = img.decodePng(png);
    if (image == null) {
      throw const FormatException('Could not decode note page');
    }
    final bytes = image.getBytes(order: img.ChannelOrder.rgba);
    final rows = List<int>.filled(image.height, 0);
    int left = image.width, right = -1, top = image.height, bottom = -1;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final i = (y * image.width + x) * 4;
        if (bytes[i + 3] < 128 ||
            math.min(bytes[i], math.min(bytes[i + 1], bytes[i + 2])) > 225) {
          continue;
        }
        rows[y]++;
        left = math.min(left, x);
        right = math.max(right, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left) return [];
    left = math.max(0, left - 16);
    right = math.min(image.width - 1, right + 16);
    top = math.max(0, top - 12);
    bottom = math.min(image.height - 1, bottom + 12);
    final bands = <({int top, int bottom})>[];
    int? start;
    int lastInk = top;
    for (int y = top; y <= bottom; y++) {
      if (rows[y] >= 3) {
        start ??= y;
        lastInk = y;
      } else if (start != null && y - lastInk > 14) {
        bands.add((top: start, bottom: lastInk + 1));
        start = null;
      }
    }
    if (start != null) bands.add((top: start, bottom: lastInk + 1));
    final width = right - left + 1;
    final maximumHeight = math.max(256, (width * 0.55).round());
    final segments = <({int top, int bottom, int lines})>[];
    int segmentTop = top, lineCount = 0;
    for (int i = 0; i < bands.length; i++) {
      final band = bands[i];
      if (lineCount > 0 && band.bottom - segmentTop > maximumHeight) {
        final previous = bands[i - 1];
        final boundary = (previous.bottom + band.top) ~/ 2;
        segments.add((top: segmentTop, bottom: boundary, lines: lineCount));
        segmentTop = boundary;
        lineCount = 0;
      }
      // Large drawings/connected brackets may have no whitespace to split on.
      while (band.bottom - segmentTop > maximumHeight && lineCount == 0) {
        final end = segmentTop + maximumHeight;
        segments.add((top: segmentTop, bottom: end, lines: 1));
        segmentTop = math.max(segmentTop + 1, end - 40);
      }
      lineCount++;
    }
    if (segmentTop <= bottom) {
      segments.add((
        top: segmentTop,
        bottom: bottom + 1,
        lines: math.max(1, lineCount),
      ));
    }
    final regions = <NoteOcrRegion>[];
    for (final segment in segments) {
      final crop = img.copyCrop(
        image,
        x: left,
        y: segment.top,
        width: width,
        height: segment.bottom - segment.top,
      );
      final scale = 768 / math.max(crop.width, crop.height);
      final scaled = img.copyResize(
        crop,
        width: math.max(1, (crop.width * scale).round()),
        height: math.max(1, (crop.height * scale).round()),
        interpolation: img.Interpolation.cubic,
      );
      final square = img.Image(width: 768, height: 768);
      img.fill(square, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(
        square,
        scaled,
        dstX: (768 - scaled.width) ~/ 2,
        dstY: (768 - scaled.height) ~/ 2,
      );
      regions.add(
        NoteOcrRegion(
          number: regions.length + 1,
          png: Uint8List.fromList(img.encodePng(square)),
          bounds: [
            left / image.width,
            segment.top / image.height,
            width / image.width,
            (segment.bottom - segment.top) / image.height,
          ],
          expectedLines: segment.lines,
        ),
      );
    }
    return regions;
  }
}
