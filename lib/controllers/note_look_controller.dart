import 'package:flutter/material.dart';
import '../models/note_settings.dart';

class NoteLookController extends ChangeNotifier {
  bool _isEditing = false;
  Offset? _draftToolbarPosition;
  Offset? _draftEditPopupPosition;
  Offset? _draftWidthPresetPopupPosition;
  NoteToolbarOrientation? _draftToolbarOrientation;
  NoteToolbarOrientation? _draftEditPopupOrientation;

  bool get isEditing => _isEditing;

  void startEditing(NoteSettings settings) {
    _isEditing = true;
    _draftToolbarPosition = Offset(
      settings.toolbarPositionX,
      settings.toolbarPositionY,
    );
    _draftEditPopupPosition = _savedEditPopupPosition(settings);
    _draftWidthPresetPopupPosition = _savedWidthPresetPopupPosition(settings);
    _draftToolbarOrientation = settings.toolbarOrientation;
    _draftEditPopupOrientation = settings.editPopupOrientation;
    notifyListeners();
  }

  void cancelEditing() {
    _resetDraft();
    notifyListeners();
  }

  NoteSettings confirmEditing(NoteSettings settings) {
    final updated = settings.copyWith(
      toolbarPositionX: _draftToolbarPosition?.dx.clamp(0.0, 1.0).toDouble(),
      toolbarPositionY: _draftToolbarPosition?.dy.clamp(0.0, 1.0).toDouble(),
      toolbarOrientation: _draftToolbarOrientation,
      editPopupPositionX: _draftEditPopupPosition?.dx
          .clamp(0.0, 1.0)
          .toDouble(),
      editPopupPositionY: _draftEditPopupPosition?.dy
          .clamp(0.0, 1.0)
          .toDouble(),
      editPopupOrientation: _draftEditPopupOrientation,
      widthPresetPopupPositionX: _draftWidthPresetPopupPosition?.dx
          .clamp(0.0, 1.0)
          .toDouble(),
      widthPresetPopupPositionY: _draftWidthPresetPopupPosition?.dy
          .clamp(0.0, 1.0)
          .toDouble(),
    );
    _resetDraft();
    notifyListeners();
    return updated;
  }

  Offset toolbarPosition(NoteSettings settings) {
    if (_isEditing) {
      return _draftToolbarPosition ??
          Offset(settings.toolbarPositionX, settings.toolbarPositionY);
    }
    return Offset(settings.toolbarPositionX, settings.toolbarPositionY);
  }

  Offset? editPopupPosition(NoteSettings settings) {
    if (_isEditing) {
      return _draftEditPopupPosition ?? _savedEditPopupPosition(settings);
    }
    return _savedEditPopupPosition(settings);
  }

  Offset? widthPresetPopupPosition(NoteSettings settings) {
    if (_isEditing) {
      return _draftWidthPresetPopupPosition ??
          _savedWidthPresetPopupPosition(settings);
    }
    return _savedWidthPresetPopupPosition(settings);
  }

  NoteToolbarOrientation toolbarOrientation(NoteSettings settings) {
    return _isEditing
        ? _draftToolbarOrientation ?? settings.toolbarOrientation
        : settings.toolbarOrientation;
  }

  NoteToolbarOrientation editPopupOrientation(NoteSettings settings) {
    return _isEditing
        ? _draftEditPopupOrientation ?? settings.editPopupOrientation
        : settings.editPopupOrientation;
  }

  void setToolbarPosition(Offset position) {
    _draftToolbarPosition = _clampOffset(position);
    notifyListeners();
  }

  void setEditPopupPosition(Offset position) {
    _draftEditPopupPosition = _clampOffset(position);
    notifyListeners();
  }

  void setWidthPresetPopupPosition(Offset position) {
    _draftWidthPresetPopupPosition = _clampOffset(position);
    notifyListeners();
  }

  void setToolbarOrientation(NoteToolbarOrientation orientation) {
    _draftToolbarOrientation = orientation;
    notifyListeners();
  }

  void setEditPopupOrientation(NoteToolbarOrientation orientation) {
    _draftEditPopupOrientation = orientation;
    notifyListeners();
  }

  Offset? _savedEditPopupPosition(NoteSettings settings) {
    final x = settings.editPopupPositionX;
    final y = settings.editPopupPositionY;
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Offset? _savedWidthPresetPopupPosition(NoteSettings settings) {
    final x = settings.widthPresetPopupPositionX;
    final y = settings.widthPresetPopupPositionY;
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Offset _clampOffset(Offset offset) => Offset(
    offset.dx.clamp(0.0, 1.0).toDouble(),
    offset.dy.clamp(0.0, 1.0).toDouble(),
  );

  void _resetDraft() {
    _isEditing = false;
    _draftToolbarPosition = null;
    _draftEditPopupPosition = null;
    _draftWidthPresetPopupPosition = null;
    _draftToolbarOrientation = null;
    _draftEditPopupOrientation = null;
  }
}
