import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/graph_canvas_object.dart';
import '../../services/graph_expression_parser.dart';
import '../color_swatch_button.dart';

class GraphConfigDialog extends StatefulWidget {
  final GraphCanvasObject initialGraph;
  final String title;

  const GraphConfigDialog({
    super.key,
    required this.initialGraph,
    required this.title,
  });

  static Future<GraphCanvasObject?> show({
    required BuildContext context,
    required GraphCanvasObject initialGraph,
    required String title,
  }) {
    return showDialog<GraphCanvasObject>(
      context: context,
      builder: (context) =>
          GraphConfigDialog(initialGraph: initialGraph, title: title),
    );
  }

  static GraphCanvasObject defaultGraph(Offset position) {
    const uuid = Uuid();
    return GraphCanvasObject(
      id: uuid.v4(),
      left: position.dx,
      top: position.dy,
      width: 360,
      height: 240,
      xAxisLabel: 'x',
      yAxisLabel: 'f(x)',
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      xTick: 1,
      yTick: 1,
      functions: [
        GraphFunctionSpec(
          id: uuid.v4(),
          equation: 'f(x)=x^2',
          color: Colors.blueAccent.toARGB32(),
        ),
      ],
    );
  }

  @override
  State<GraphConfigDialog> createState() => _GraphConfigDialogState();
}

class _GraphConfigDialogState extends State<GraphConfigDialog> {
  static const _palette = [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.green,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.teal,
    Colors.pinkAccent,
    Colors.black,
  ];

  late final TextEditingController _xAxisController;
  late final TextEditingController _yAxisController;
  late final TextEditingController _xMinController;
  late final TextEditingController _xMaxController;
  late final TextEditingController _yMinController;
  late final TextEditingController _yMaxController;
  late final TextEditingController _xTickController;
  late final TextEditingController _yTickController;
  late final List<_FunctionRowState> _functions;
  String? _error;

  @override
  void initState() {
    super.initState();
    final graph = widget.initialGraph;
    _xAxisController = TextEditingController(text: graph.xAxisLabel);
    _yAxisController = TextEditingController(text: graph.yAxisLabel);
    _xMinController = TextEditingController(text: _formatNumber(graph.xMin));
    _xMaxController = TextEditingController(text: _formatNumber(graph.xMax));
    _yMinController = TextEditingController(text: _formatNumber(graph.yMin));
    _yMaxController = TextEditingController(text: _formatNumber(graph.yMax));
    _xTickController = TextEditingController(text: _formatNumber(graph.xTick));
    _yTickController = TextEditingController(text: _formatNumber(graph.yTick));
    _functions = graph.functions.map(_FunctionRowState.fromSpec).toList();
  }

  @override
  void dispose() {
    _xAxisController.dispose();
    _yAxisController.dispose();
    _xMinController.dispose();
    _xMaxController.dispose();
    _yMinController.dispose();
    _yMaxController.dispose();
    _xTickController.dispose();
    _yTickController.dispose();
    for (final function in _functions) {
      function.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _textField(_xAxisController, 'X axis')),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(_yAxisController, 'Y axis')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _textField(_xMinController, 'X min', number: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _textField(_xMaxController, 'X max', number: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _textField(_xTickController, 'X tick', number: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _textField(_yMinController, 'Y min', number: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _textField(_yMaxController, 'Y max', number: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _textField(_yTickController, 'Y tick', number: true),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Functions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addFunction,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              for (int i = 0; i < _functions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _functionRow(i),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Confirm')),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  Widget _functionRow(int index) {
    final row = _functions[index];
    return Row(
      children: [
        ColorSwatchButton(
          selectedColor: Color(row.color),
          palette: _palette,
          onPick: (color) => setState(() => row.color = color.toARGB32()),
        ),
        const SizedBox(width: 10),
        Expanded(child: _textField(row.controller, 'Equation ${index + 1}')),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove function',
          onPressed: _functions.length == 1
              ? null
              : () => _removeFunction(index),
        ),
      ],
    );
  }

  void _addFunction() {
    const uuid = Uuid();
    final index = _functions.length;
    final color = _palette[index % _palette.length].toARGB32();
    setState(() {
      _functions.add(
        _FunctionRowState(
          id: uuid.v4(),
          equation: 'f${index + 1}(x)=x',
          color: color,
        ),
      );
    });
  }

  void _removeFunction(int index) {
    setState(() {
      final removed = _functions.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    final xMin = double.tryParse(_xMinController.text.trim());
    final xMax = double.tryParse(_xMaxController.text.trim());
    final yMin = double.tryParse(_yMinController.text.trim());
    final yMax = double.tryParse(_yMaxController.text.trim());
    final xTick = double.tryParse(_xTickController.text.trim());
    final yTick = double.tryParse(_yTickController.text.trim());

    if (xMin == null ||
        xMax == null ||
        yMin == null ||
        yMax == null ||
        xTick == null ||
        yTick == null) {
      setState(() => _error = 'Ranges and ticks must be valid numbers.');
      return;
    }
    if (!GraphExpressionParser.isFiniteRange(xMin, xMax) ||
        !GraphExpressionParser.isFiniteRange(yMin, yMax)) {
      setState(
        () =>
            _error = 'Ranges must be finite and min must be smaller than max.',
      );
      return;
    }
    if (!xTick.isFinite || !yTick.isFinite || xTick <= 0 || yTick <= 0) {
      setState(() => _error = 'Tick scale must be positive.');
      return;
    }

    final functions = <GraphFunctionSpec>[];
    for (final row in _functions) {
      final equation = row.controller.text.trim();
      if (equation.isEmpty) {
        setState(() => _error = 'Function equations cannot be empty.');
        return;
      }
      final error = GraphExpressionParser.validate(equation);
      if (error != null) {
        setState(() => _error = '$equation: $error');
        return;
      }
      functions.add(
        GraphFunctionSpec(id: row.id, equation: equation, color: row.color),
      );
    }

    Navigator.of(context).pop(
      widget.initialGraph.copyWith(
        xAxisLabel: _xAxisController.text.trim().isEmpty
            ? 'x'
            : _xAxisController.text.trim(),
        yAxisLabel: _yAxisController.text.trim().isEmpty
            ? 'y'
            : _yAxisController.text.trim(),
        xMin: xMin,
        xMax: xMax,
        yMin: yMin,
        yMax: yMax,
        xTick: xTick,
        yTick: yTick,
        functions: functions,
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }
}

class _FunctionRowState {
  final String id;
  final TextEditingController controller;
  int color;

  _FunctionRowState({
    required this.id,
    required String equation,
    required this.color,
  }) : controller = TextEditingController(text: equation);

  factory _FunctionRowState.fromSpec(GraphFunctionSpec spec) {
    return _FunctionRowState(
      id: spec.id,
      equation: spec.equation,
      color: spec.color,
    );
  }

  void dispose() {
    controller.dispose();
  }
}
