import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../utils/pdf_coordinate_mapper.dart';

class PdfScreenshotService {
  static Future<String?> captureSelectionScreenshot({
    required PdfDocument document,
    required Rect selectionRect,
    required PdfCoordinateMapper mapper,
    required String id,
  }) async {
    final spanned = mapper.findSpannedPages(selectionRect);
    final startPageIndex = spanned[0];
    final endPageIndex = spanned[1];

    if (startPageIndex == -1 || endPageIndex == -1) return null;

    const double scaleFactor = 4.0;
    List<img.Image> renderedPages = [];
    int totalWidth = 0;
    int totalHeight = 0;

    for (int i = startPageIndex; i <= endPageIndex; i++) {
      final page = await document.getPage(i + 1);
      final pageImage = await page.render(
        width: mapper.pageWidths[i] * scaleFactor,
        height: mapper.pageHeights[i] * scaleFactor,
        format: PdfPageImageFormat.png,
      );
      final decoded = img.decodeImage(pageImage!.bytes);
      if (decoded != null) {
        renderedPages.add(decoded);
        totalWidth = totalWidth > decoded.width ? totalWidth : decoded.width;
        totalHeight += decoded.height;
      }
      await page.close();
    }

    if (renderedPages.isEmpty) return null;

    final stitchedImage = img.Image(width: totalWidth, height: totalHeight);
    img.fill(stitchedImage, color: img.ColorRgb8(255, 255, 255));

    int currentY = 0;
    for (var pageImg in renderedPages) {
      img.compositeImage(stitchedImage, pageImg, dstY: currentY);
      currentY += pageImg.height;
    }

    final coords = mapper.screenToPageRelative(selectionRect, startPageIndex);
    final firstPage = await document.getPage(startPageIndex + 1);

    int cropX = (coords.left * firstPage.width * scaleFactor).toInt();
    int cropY = (coords.top * firstPage.height * scaleFactor).toInt();
    int cropWidth = (coords.width * firstPage.width * scaleFactor).toInt();
    int cropHeight = (coords.height * firstPage.height * scaleFactor).toInt();

    await firstPage.close();

    cropX = cropX.clamp(0, stitchedImage.width - 1);
    cropY = cropY.clamp(0, stitchedImage.height - 1);
    cropWidth = cropWidth.clamp(1, stitchedImage.width - cropX);
    cropHeight = cropHeight.clamp(1, stitchedImage.height - cropY);

    final croppedImage = img.copyCrop(
      stitchedImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    const int padding = 20;
    final bgWidth = croppedImage.width + 2 * padding;
    final bgHeight = croppedImage.height + 2 * padding;
    final backgroundImage = img.Image(width: bgWidth, height: bgHeight);
    img.fill(backgroundImage, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      backgroundImage,
      croppedImage,
      dstX: padding,
      dstY: padding,
    );

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/screenshot_$id.png';
    final file = File(path);
    await file.writeAsBytes(img.encodePng(backgroundImage));

    return path;
  }
}
