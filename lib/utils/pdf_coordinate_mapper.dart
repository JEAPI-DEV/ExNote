import 'package:flutter/material.dart';

class PdfCoordinateMapper {
  final List<double> pageWidths;
  final List<double> pageHeights;
  final Size viewSize;
  final double scrollOffset;

  late final double viewAspectRatio;
  late final List<double> pageScreenTops;
  late final List<double> pageScreenHeights;
  late final List<double> pageScreenWidths;
  late final List<double> pageScreenOffsetXs;

  PdfCoordinateMapper({
    required this.pageWidths,
    required this.pageHeights,
    required this.viewSize,
    required this.scrollOffset,
  }) {
    viewAspectRatio = viewSize.width / viewSize.height;
    pageScreenTops = [];
    pageScreenHeights = [];
    pageScreenWidths = [];
    pageScreenOffsetXs = [];

    double cumTop = 0;
    for (int i = 0; i < pageWidths.length; i++) {
      pageScreenTops.add(cumTop - scrollOffset);
      final pageAspectRatio = pageWidths[i] / pageHeights[i];
      double actualPageHeight, actualPageWidth, offsetX;
      if (pageAspectRatio > viewAspectRatio) {
        actualPageWidth = viewSize.width;
        actualPageHeight = viewSize.width / pageAspectRatio;
        offsetX = 0;
      } else {
        actualPageHeight = viewSize.height;
        actualPageWidth = viewSize.height * pageAspectRatio;
        offsetX = (viewSize.width - actualPageWidth) / 2;
      }
      pageScreenHeights.add(actualPageHeight);
      pageScreenWidths.add(actualPageWidth);
      pageScreenOffsetXs.add(offsetX);
      cumTop += actualPageHeight;
    }
  }

  List<int> findSpannedPages(Rect selectionRect) {
    int startPage = -1;
    int endPage = -1;
    for (int i = 0; i < pageScreenTops.length; i++) {
      final top = pageScreenTops[i];
      final bottom = top + pageScreenHeights[i];
      if (selectionRect.bottom > top && selectionRect.top < bottom) {
        if (startPage == -1) startPage = i;
        endPage = i;
      }
    }
    return [startPage, endPage];
  }

  int findPageIndexForY(double screenY) {
    double cumulativeTop = 0;
    for (int i = 0; i < pageScreenHeights.length; i++) {
      final pageScreenTop = cumulativeTop - scrollOffset;
      if (screenY >= pageScreenTop &&
          screenY < pageScreenTop + pageScreenHeights[i]) {
        return i;
      }
      cumulativeTop += pageScreenHeights[i];
    }
    return 0;
  }

  ({double left, double top, double width, double height}) screenToPageRelative(
    Rect selectionRect,
    int pageIndex,
  ) {
    final offsetX = pageScreenOffsetXs[pageIndex];
    final pageWidth = pageScreenWidths[pageIndex];
    final pageHeight = pageScreenHeights[pageIndex];

    double cumulativeTop = 0;
    for (int i = 0; i < pageIndex; i++) {
      cumulativeTop += pageScreenHeights[i];
    }

    return (
      left: (selectionRect.left - offsetX) / pageWidth,
      top: (selectionRect.top - cumulativeTop + scrollOffset) / pageHeight,
      width: selectionRect.width / pageWidth,
      height: selectionRect.height / pageHeight,
    );
  }
}
