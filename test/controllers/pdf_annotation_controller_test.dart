import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';

import 'package:exnote/controllers/pdf_annotation_controller.dart';
import 'package:exnote/models/drawing_tool.dart';
import 'package:exnote/models/pdf_annotation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfAnnotationController', () {
    test('commits a pen stroke to the active page and snapshots it', () {
      final controller = PdfAnnotationController(onContentChanged: () {});

      controller.beginStroke(0, const Offset(10, 10));
      controller.extendStroke(const Offset(30, 30));
      controller.endStroke();

      expect(controller.annotations[0]!.lines, hasLength(1));
      expect(controller.snapshot().single.pageIndex, 0);
      expect(controller.canUndo, isTrue);

      controller.dispose();
    });

    test('supports undo and redo', () {
      final controller = PdfAnnotationController(onContentChanged: () {});

      controller.beginStroke(0, const Offset(10, 10));
      controller.extendStroke(const Offset(30, 30));
      controller.endStroke();
      expect(controller.annotations[0]!.lines, hasLength(1));

      controller.undo();
      expect(controller.annotations[0]!.lines, isEmpty);

      controller.redo();
      expect(controller.annotations[0]!.lines, hasLength(1));

      controller.dispose();
    });

    test('keeps annotations separate per page', () {
      final controller = PdfAnnotationController(onContentChanged: () {});

      controller.beginStroke(0, const Offset(10, 10));
      controller.extendStroke(const Offset(30, 30));
      controller.endStroke();

      controller.setActivePage(1);
      expect(controller.annotations[0]!.lines, hasLength(1));
      expect(controller.activeSketch.value.lines, isEmpty);

      controller.beginStroke(1, const Offset(5, 5));
      controller.extendStroke(const Offset(6, 6));
      controller.endStroke();

      expect(controller.annotations[1]!.lines, hasLength(1));
      expect(controller.snapshot(), hasLength(2));

      controller.dispose();
    });

    test('round-trips a snapshot through load', () {
      final controller = PdfAnnotationController(onContentChanged: () {});

      controller.beginStroke(0, const Offset(10, 10));
      controller.extendStroke(const Offset(30, 30));
      controller.endStroke();
      final snapshot = controller.snapshot();

      final restored = PdfAnnotationController(onContentChanged: () {});
      restored.load(snapshot);

      expect(restored.annotations[0]!.lines, hasLength(1));
      expect(
        jsonDecode(restored.snapshot().single.sketchJson),
        isA<Map<String, dynamic>>(),
      );

      controller.dispose();
      restored.dispose();
    });

    test('stroke eraser removes a line', () {
      final controller = PdfAnnotationController(onContentChanged: () {});

      controller.beginStroke(0, const Offset(0, 0));
      controller.extendStroke(const Offset(100, 0));
      controller.endStroke();
      expect(controller.annotations[0]!.lines, hasLength(1));

      controller.toolNotifier.value = DrawingTool.strokeEraser;
      controller.beginStroke(0, const Offset(50, 0));
      controller.extendStroke(const Offset(50, 0));
      controller.endStroke();

      expect(controller.annotations[0]!.lines, isEmpty);

      controller.dispose();
    });

    test('drops empty sketches from the snapshot', () {
      final controller = PdfAnnotationController(onContentChanged: () {});
      controller.setActivePage(3);
      expect(controller.snapshot(), isEmpty);
      controller.dispose();
    });

    test('serializes annotation with a page index', () {
      final annotation = PdfAnnotation(
        pageIndex: 2,
        sketchJson: '{"lines":[]}',
      );

      final json = annotation.toJson();
      final restored = PdfAnnotation.fromJson(json);

      expect(restored.pageIndex, 2);
      expect(restored.sketchJson, '{"lines":[]}');
    });
  });
}
