import 'latex_plain.dart';
import 'math_view.dart';

/// One formula that cannot be drawn, or LaTeX written outside \( \).
class MathIssue {
  const MathIssue({
    required this.where,
    required this.path,
    required this.formula,
    required this.error,
    this.moduleId,
  });

  /// e.g. "lesson 12", "card 40", "kv case_set_7".
  final String where;
  final int? moduleId;

  /// JSON path inside the item, e.g. "fr.blocks[3].content".
  final String path;
  final String formula;
  final String error;

  String toLine() =>
      'module ${moduleId ?? '-'} | $where | $path | $formula | $error';
}

final _inlineCodeOrFence = RegExp(r'```[\s\S]*?```|`[^`\n]+`');
final _bareCommand = RegExp(r'\\[a-zA-Z]{2,}');
final _bareScript = RegExp(
  r'(?<![\w\\])[A-Za-z][_^](\{[^}\s]*\}|[A-Za-z0-9])(?!\w)',
);

/// Checks one string. [isLatex]: the whole string is a formula (an
/// equation block's "latex" field).
void auditString(
  String s, {
  bool isLatex = false,
  required void Function(String formula, String error) report,
}) {
  final t = normalizeLatexEscapes(s);
  if (isLatex) {
    if (t.trim().isEmpty) return;
    final e = latexParseError(t);
    if (e != null) report(t, e);
    return;
  }
  if (t.trimLeft().startsWith('<svg')) return;
  for (final p in splitMath(t)) {
    if (p.isMath) {
      final opener = t.substring(p.start, p.start + 2);
      final closed = switch (opener) {
        r'\(' => p.end - 2 >= p.start + 2 && t.startsWith(r'\)', p.end - 2),
        r'\[' => p.end - 2 >= p.start + 2 && t.startsWith(r'\]', p.end - 2),
        _ => true,
      };
      if (!closed) {
        report(p.text, 'unclosed $opener');
        continue;
      }
      if (p.text.trim().isEmpty) continue;
      final e = latexParseError(p.text);
      if (e != null) report(p.text, e);
    } else {
      final text = p.text.replaceAll(_inlineCodeOrFence, ' ');
      final m = _bareCommand.firstMatch(text) ?? _bareScript.firstMatch(text);
      if (m != null) {
        final from = m.start > 20 ? m.start - 20 : 0;
        final to = m.end + 20 < text.length ? m.end + 20 : text.length;
        report(text.substring(from, to).trim(), 'LaTeX outside \\( \\)');
      }
    }
  }
}

/// Walks any decoded JSON and checks every string in it.
List<MathIssue> auditJson(
  Object? json, {
  required String where,
  int? moduleId,
}) {
  final out = <MathIssue>[];
  void visit(Object? v, String path, String? key) {
    if (v is Map) {
      v.forEach((k, x) => visit(x, path.isEmpty ? '$k' : '$path.$k', '$k'));
      return;
    }
    if (v is List) {
      for (var i = 0; i < v.length; i++) {
        visit(v[i], '$path[$i]', key);
      }
      return;
    }
    if (v is! String || v.isEmpty) return;
    auditString(
      v,
      isLatex: key == 'latex',
      report: (formula, error) => out.add(
        MathIssue(
          where: where,
          moduleId: moduleId,
          path: path,
          formula: formula,
          error: error,
        ),
      ),
    );
  }

  visit(json, '', null);
  return out;
}
