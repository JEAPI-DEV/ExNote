import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../controllers/note_look_controller.dart';
import '../controllers/selection_edit_controller.dart';
import '../models/drawing_tool.dart';
import '../models/note_settings.dart';
import '../models/undo_action.dart';
import '../utils/note_look_layout.dart';
import 'edit_selection_controls.dart';
import 'note_toolbar.dart';

class NoteLookOverlay extends StatefulWidget {
  final NoteSettings settings;
  final NoteLookController controller;
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final void Function(UndoAction) onAction;
  final void Function(NoteSettings Function(NoteSettings)) onSettingsChanged;

  const NoteLookOverlay({
    super.key,
    required this.settings,
    required this.controller,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
    required this.onSettingsChanged,
  });

  @override
  State<NoteLookOverlay> createState() => _NoteLookOverlayState();
}

class _NoteLookOverlayState extends State<NoteLookOverlay> {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();
  late SelectionEditController _selectionEditController;

  Color _editColor = Colors.black;
  double _editWidth = 2.0;
  Size _toolbarSize = Size.zero;
  Offset? _toolbarDragGrabOffset;
  Offset? _editPopupDragGrabOffset;
  Offset? _widthPresetPopupDragGrabOffset;

  @override
  void initState() {
    super.initState();
    _selectionEditController = _createSelectionEditController();
    widget.selectionNotifier.addListener(_handleSelectionChanged);
    widget.toolNotifier.addListener(_handleToolChanged);
    _syncEditControlsFromSelection();
  }

  @override
  void didUpdateWidget(NoteLookOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sketchNotifier != widget.sketchNotifier ||
        oldWidget.selectionNotifier != widget.selectionNotifier ||
        oldWidget.onAction != widget.onAction) {
      oldWidget.selectionNotifier.removeListener(_handleSelectionChanged);
      widget.selectionNotifier.addListener(_handleSelectionChanged);
      _selectionEditController = _createSelectionEditController();
      _syncEditControlsFromSelection();
    }

    if (oldWidget.toolNotifier != widget.toolNotifier) {
      oldWidget.toolNotifier.removeListener(_handleToolChanged);
      widget.toolNotifier.addListener(_handleToolChanged);
    }
  }

  @override
  void dispose() {
    widget.selectionNotifier.removeListener(_handleSelectionChanged);
    widget.toolNotifier.removeListener(_handleToolChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                key: _stackKey,
                children: [
                  _buildToolbarLayer(constraints),
                  _buildEditControlsLayer(constraints),
                  if (widget.controller.isEditing)
                    _buildWidthPresetPopupLayer(constraints),
                  if (widget.controller.isEditing) _buildEditorPanel(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  SelectionEditController _createSelectionEditController() {
    return SelectionEditController(
      sketchNotifier: widget.sketchNotifier,
      selectionNotifier: widget.selectionNotifier,
      onAction: widget.onAction,
    );
  }

  Widget _buildToolbarLayer(BoxConstraints constraints) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateToolbarSize());

    final position = widget.controller.toolbarPosition(widget.settings);
    final toolbarSize = _toolbarSize == Size.zero
        ? const Size(1, 1)
        : _toolbarSize;
    final topLeft = NoteLookLayout.topLeftFromNormalized(
      constraints: constraints,
      itemSize: toolbarSize,
      normalized: position,
    );
    final toolbar = KeyedSubtree(
      key: _toolbarKey,
      child: NoteToolbar(
        colorNotifier: widget.colorNotifier,
        widthNotifier: widget.widthNotifier,
        toolNotifier: widget.toolNotifier,
        sketchNotifier: widget.sketchNotifier,
        selectionNotifier: widget.selectionNotifier,
        onAction: widget.onAction,
        orientation: widget.controller.toolbarOrientation(widget.settings),
        widthPresetPopupPosition: widget.controller.widthPresetPopupPosition(
          widget.settings,
        ),
      ),
    );

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: widget.controller.isEditing
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  _startToolbarDrag(details.globalPosition, topLeft),
              onPanUpdate: (details) => _updateToolbarDrag(
                constraints,
                toolbarSize,
                details.globalPosition,
              ),
              onPanEnd: (_) => _endToolbarDrag(),
              onPanCancel: _endToolbarDrag,
              child: AbsorbPointer(child: toolbar),
            )
          : toolbar,
    );
  }

  Widget _buildEditControlsLayer(BoxConstraints constraints) {
    final shouldShow =
        widget.controller.isEditing ||
        (widget.toolNotifier.value == DrawingTool.editSelection &&
            widget.selectionNotifier.value.isNotEmpty);
    if (!shouldShow) return const SizedBox.shrink();

    final orientation = widget.controller.editPopupOrientation(widget.settings);
    final popupSize = NoteLookLayout.editPopupSize(orientation);
    final topLeft = _editPopupTopLeft(constraints, popupSize);
    final controls = EditSelectionControls(
      editColor: _editColor,
      editWidth: _editWidth,
      orientation: orientation,
      onColorChanged: (color) {
        if (widget.controller.isEditing) return;
        setState(() => _editColor = color);
        _selectionEditController.applyStyle(color: color);
      },
      onWidthChanged: (value) {
        if (widget.controller.isEditing) return;
        setState(() => _editWidth = value);
      },
      onWidthChangeEnd: () {
        if (widget.controller.isEditing) return;
        _selectionEditController.applyStyle(strokeWidth: _editWidth);
      },
      onMirrorX: () {
        if (widget.controller.isEditing) return;
        _selectionEditController.mirror(mirrorOverXAxis: true);
      },
      onMirrorY: () {
        if (widget.controller.isEditing) return;
        _selectionEditController.mirror(mirrorOverXAxis: false);
      },
    );

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: widget.controller.isEditing
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  _startEditPopupDrag(details.globalPosition, topLeft),
              onPanUpdate: (details) => _updateEditPopupDrag(
                constraints,
                popupSize,
                details.globalPosition,
              ),
              onPanEnd: (_) => _endEditPopupDrag(),
              onPanCancel: _endEditPopupDrag,
              child: AbsorbPointer(child: controls),
            )
          : controls,
    );
  }

  Widget _buildWidthPresetPopupLayer(BoxConstraints constraints) {
    final popupSize = NoteLookLayout.widthPresetPopupSize;
    final topLeft = _widthPresetPopupTopLeft(constraints, popupSize);

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: popupSize.width,
      height: popupSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) =>
            _startWidthPresetPopupDrag(details.globalPosition, topLeft),
        onPanUpdate: (details) => _updateWidthPresetPopupDrag(
          constraints,
          popupSize,
          details.globalPosition,
        ),
        onPanEnd: (_) => _endWidthPresetPopupDrag(),
        onPanCancel: _endWidthPresetPopupDrag,
        child: AbsorbPointer(
          child: _WidthPresetPopupPreview(
            selectedWidth: widget.widthNotifier.value,
          ),
        ),
      ),
    );
  }

  Widget _buildEditorPanel() {
    final toolbarOrientation = widget.controller.toolbarOrientation(
      widget.settings,
    );
    final editOrientation = widget.controller.editPopupOrientation(
      widget.settings,
    );

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.open_with),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Adjust note look',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Drag toolbar, edit popup, and size popup, then confirm.',
                    ),
                  ],
                ),
              ),
              _OrientationSection(
                title: 'Toolbar',
                orientation: toolbarOrientation,
                onChanged: widget.controller.setToolbarOrientation,
              ),
              const SizedBox(width: 12),
              _OrientationSection(
                title: 'Edit bar',
                orientation: editOrientation,
                onChanged: widget.controller.setEditPopupOrientation,
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: widget.controller.cancelEditing,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _confirmEditing,
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _editPopupTopLeft(BoxConstraints constraints, Size popupSize) {
    final normalized = widget.controller.editPopupPosition(widget.settings);
    if (normalized != null) {
      return NoteLookLayout.topLeftFromNormalized(
        constraints: constraints,
        itemSize: popupSize,
        normalized: normalized,
      );
    }

    final toolbarPosition = widget.controller.toolbarPosition(widget.settings);
    final toolbarSize = _toolbarSize == Size.zero
        ? const Size(1, 1)
        : _toolbarSize;
    final toolbarTopLeft = NoteLookLayout.topLeftFromNormalized(
      constraints: constraints,
      itemSize: toolbarSize,
      normalized: toolbarPosition,
    );
    return NoteLookLayout.autoEditPopupTopLeft(
      constraints: constraints,
      toolbarSize: toolbarSize,
      toolbarTopLeft: toolbarTopLeft,
      popupSize: popupSize,
    );
  }

  Offset _widthPresetPopupTopLeft(BoxConstraints constraints, Size popupSize) {
    final normalized = widget.controller.widthPresetPopupPosition(
      widget.settings,
    );
    if (normalized != null) {
      return NoteLookLayout.topLeftFromNormalized(
        constraints: constraints,
        itemSize: popupSize,
        normalized: normalized,
      );
    }

    final toolbarPosition = widget.controller.toolbarPosition(widget.settings);
    final toolbarSize = _toolbarSize == Size.zero
        ? const Size(1, 1)
        : _toolbarSize;
    final toolbarTopLeft = NoteLookLayout.topLeftFromNormalized(
      constraints: constraints,
      itemSize: toolbarSize,
      normalized: toolbarPosition,
    );
    return NoteLookLayout.autoWidthPresetPopupTopLeft(
      constraints: constraints,
      toolbarSize: toolbarSize,
      toolbarTopLeft: toolbarTopLeft,
      popupSize: popupSize,
    );
  }

  void _confirmEditing() {
    widget.onSettingsChanged(
      (settings) => widget.controller.confirmEditing(settings),
    );
  }

  void _startToolbarDrag(Offset globalPosition, Offset topLeft) {
    final local = _globalToLocal(globalPosition);
    if (local == null) return;
    _toolbarDragGrabOffset = local - topLeft;
  }

  void _updateToolbarDrag(
    BoxConstraints constraints,
    Size toolbarSize,
    Offset globalPosition,
  ) {
    final local = _globalToLocal(globalPosition);
    final grabOffset = _toolbarDragGrabOffset;
    if (local == null || grabOffset == null) return;
    widget.controller.setToolbarPosition(
      NoteLookLayout.normalizedFromTopLeft(
        constraints: constraints,
        itemSize: toolbarSize,
        topLeft: local - grabOffset,
      ),
    );
  }

  void _endToolbarDrag() {
    _toolbarDragGrabOffset = null;
  }

  void _startEditPopupDrag(Offset globalPosition, Offset topLeft) {
    final local = _globalToLocal(globalPosition);
    if (local == null) return;
    _editPopupDragGrabOffset = local - topLeft;
  }

  void _updateEditPopupDrag(
    BoxConstraints constraints,
    Size popupSize,
    Offset globalPosition,
  ) {
    final local = _globalToLocal(globalPosition);
    final grabOffset = _editPopupDragGrabOffset;
    if (local == null || grabOffset == null) return;
    widget.controller.setEditPopupPosition(
      NoteLookLayout.normalizedFromTopLeft(
        constraints: constraints,
        itemSize: popupSize,
        topLeft: local - grabOffset,
      ),
    );
  }

  void _endEditPopupDrag() {
    _editPopupDragGrabOffset = null;
  }

  void _startWidthPresetPopupDrag(Offset globalPosition, Offset topLeft) {
    final local = _globalToLocal(globalPosition);
    if (local == null) return;
    _widthPresetPopupDragGrabOffset = local - topLeft;
  }

  void _updateWidthPresetPopupDrag(
    BoxConstraints constraints,
    Size popupSize,
    Offset globalPosition,
  ) {
    final local = _globalToLocal(globalPosition);
    final grabOffset = _widthPresetPopupDragGrabOffset;
    if (local == null || grabOffset == null) return;
    widget.controller.setWidthPresetPopupPosition(
      NoteLookLayout.normalizedFromTopLeft(
        constraints: constraints,
        itemSize: popupSize,
        topLeft: local - grabOffset,
      ),
    );
  }

  void _endWidthPresetPopupDrag() {
    _widthPresetPopupDragGrabOffset = null;
  }

  Offset? _globalToLocal(Offset globalPosition) {
    final renderBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.globalToLocal(globalPosition);
  }

  void _updateToolbarSize() {
    if (!mounted) return;

    final renderBox =
        _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    if (_toolbarSize == size) return;

    setState(() {
      _toolbarSize = size;
    });
  }

  void _handleSelectionChanged() {
    _syncEditControlsFromSelection();
    if (mounted) setState(() {});
  }

  void _handleToolChanged() {
    if (mounted) setState(() {});
  }

  void _syncEditControlsFromSelection() {
    final selected = widget.selectionNotifier.value;
    if (selected.isEmpty) return;
    _editColor = Color(selected.first.color);
    _editWidth = selected.first.width;
  }
}

class _OrientationSection extends StatelessWidget {
  final String title;
  final NoteToolbarOrientation orientation;
  final ValueChanged<NoteToolbarOrientation> onChanged;

  const _OrientationSection({
    required this.title,
    required this.orientation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        SegmentedButton<NoteToolbarOrientation>(
          segments: const [
            ButtonSegment(
              value: NoteToolbarOrientation.horizontal,
              label: Text('Horizontal'),
              icon: Icon(Icons.view_week),
            ),
            ButtonSegment(
              value: NoteToolbarOrientation.vertical,
              label: Text('Vertical'),
              icon: Icon(Icons.view_agenda),
            ),
          ],
          selected: {orientation},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

class _WidthPresetPopupPreview extends StatelessWidget {
  final double selectedWidth;

  const _WidthPresetPopupPreview({required this.selectedWidth});

  static const _previewPresets = [2.0, 6.0, 12.0];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final preset in _previewPresets)
              _WidthPresetPreviewTile(
                preset: preset,
                selected: selectedWidth.round() == preset.round(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WidthPresetPreviewTile extends StatelessWidget {
  final double preset;
  final bool selected;

  const _WidthPresetPreviewTile({required this.preset, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 64,
      height: 58,
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.secondary.withValues(alpha: 0.16)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? colorScheme.secondary
              : colorScheme.outline.withValues(alpha: 0.24),
          width: selected ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(
          preset.round().toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? colorScheme.secondary : null,
          ),
        ),
      ),
    );
  }
}
