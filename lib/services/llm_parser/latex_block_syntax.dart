import 'package:markdown/markdown.dart';
import 'latex_inline_syntax.dart';

class LatexBlockSyntax extends BlockSyntax {
  @override
  RegExp get pattern =>
      RegExp(r'^\s*(?:(\${1,2})|(\\\[)|(\\\]))\s*$', multiLine: true);

  LatexBlockSyntax() : super();

  @override
  List<Line> parseChildLines(BlockParser parser) {
    parser.advance(); // Skip opening delimiter

    final childLines = <Line>[];
    while (!parser.isDone) {
      if (pattern.hasMatch(parser.current.content)) {
        parser.advance(); // Skip closing delimiter
        break;
      }
      childLines.add(parser.current);
      parser.advance();
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final lines = parseChildLines(parser);
    final content = lines.map((e) => e.content).join('\n').trim();
    final textElement = Element.text('latex', fixLatex(content));
    textElement.attributes['MathStyle'] = 'display';

    return Element('p', [textElement]);
  }
}
