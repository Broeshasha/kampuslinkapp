/// A tiny syntax colouring for lesson code (Python first; C-like "//"
/// comments work too). Not a parser: good enough for teaching snippets.
enum CodeTokenKind { plain, keyword, builtin, string, number, comment }

class CodeToken {
  const CodeToken(this.text, this.kind);

  final String text;
  final CodeTokenKind kind;

  @override
  bool operator ==(Object other) =>
      other is CodeToken && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => '${kind.name}($text)';
}

const _keywords = {
  'and',
  'as',
  'assert',
  'break',
  'class',
  'continue',
  'def',
  'del',
  'elif',
  'else',
  'except',
  'False',
  'finally',
  'for',
  'from',
  'global',
  'if',
  'import',
  'in',
  'is',
  'lambda',
  'None',
  'nonlocal',
  'not',
  'or',
  'pass',
  'raise',
  'return',
  'True',
  'try',
  'while',
  'with',
  'yield',
  'match',
  'case',
};

const _builtins = {
  'print',
  'input',
  'len',
  'range',
  'int',
  'float',
  'str',
  'bool',
  'list',
  'dict',
  'set',
  'tuple',
  'type',
  'abs',
  'min',
  'max',
  'sum',
  'round',
  'sorted',
  'enumerate',
  'zip',
  'open',
  'map',
  'filter',
  'isinstance',
};

final _token = RegExp(
  r'''(#.*$|//.*$)'''
  r'''|("""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27)'''
  r'''|("(?:\\.|[^"\\])*"?|'(?:\\.|[^'\\])*'?)'''
  r'''|(\b\d+(?:\.\d+)?\b)'''
  r'''|([A-Za-z_][A-Za-z0-9_]*)''',
);

/// The tokens of ONE line of code (strings never span lines here).
List<CodeToken> tokenizeLine(String line) {
  final out = <CodeToken>[];
  var pos = 0;
  void plain(int end) {
    if (end > pos) {
      out.add(CodeToken(line.substring(pos, end), CodeTokenKind.plain));
    }
  }

  for (final m in _token.allMatches(line)) {
    final kind = m.group(1) != null
        ? CodeTokenKind.comment
        : (m.group(2) != null || m.group(3) != null)
        ? CodeTokenKind.string
        : m.group(4) != null
        ? CodeTokenKind.number
        : _keywords.contains(m.group(5))
        ? CodeTokenKind.keyword
        : _builtins.contains(m.group(5))
        ? CodeTokenKind.builtin
        : CodeTokenKind.plain;
    plain(m.start);
    if (kind == CodeTokenKind.plain &&
        out.isNotEmpty &&
        out.last.kind == CodeTokenKind.plain) {
      final last = out.removeLast();
      out.add(CodeToken(last.text + m.group(0)!, CodeTokenKind.plain));
    } else {
      out.add(CodeToken(m.group(0)!, kind));
    }
    pos = m.end;
  }
  if (pos < line.length) {
    final rest = line.substring(pos);
    if (out.isNotEmpty && out.last.kind == CodeTokenKind.plain) {
      final last = out.removeLast();
      out.add(CodeToken(last.text + rest, CodeTokenKind.plain));
    } else {
      out.add(CodeToken(rest, CodeTokenKind.plain));
    }
  }
  return out;
}

/// A ```fenced``` part of a paragraph, or plain text between fences.
class TextPart {
  const TextPart.text(this.text) : code = false, language = '';
  const TextPart.code(this.text, this.language) : code = true;

  final String text;
  final bool code;
  final String language;
}

final _fence = RegExp(r'```([A-Za-z0-9_+#-]*)[ \t]*\n?([\s\S]*?)```');

/// Splits a paragraph on ```lang ... ``` fences (an unclosed fence stays
/// text). Empty text parts are dropped.
List<TextPart> splitFences(String text) {
  if (!text.contains('```')) return [TextPart.text(text)];
  final out = <TextPart>[];
  var pos = 0;
  for (final m in _fence.allMatches(text)) {
    final before = text.substring(pos, m.start).trim();
    if (before.isNotEmpty) out.add(TextPart.text(before));
    final code = (m.group(2) ?? '').replaceAll(RegExp(r'\s+$'), '');
    out.add(TextPart.code(code, m.group(1) ?? ''));
    pos = m.end;
  }
  final rest = text.substring(pos).trim();
  if (rest.isNotEmpty) out.add(TextPart.text(rest));
  return out;
}
