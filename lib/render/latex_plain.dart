/// Pure text helpers for math (no Flutter): split a content string into
/// text / inline math / display math, undo double escaping, and turn LaTeX
/// into readable Unicode for places that cannot draw a formula
/// (notifications, semantics, share text, search index, SVG text).
library;

enum MathPieceKind { text, inline, display }

/// One piece of a content string. For math, [text] is the formula without
/// its delimiters; [start]/[end] cover the delimiters in the source string.
class MathPiece {
  const MathPiece(this.kind, this.text, this.start, this.end);

  final MathPieceKind kind;
  final String text;
  final int start;
  final int end;

  bool get isMath => kind != MathPieceKind.text;

  @override
  String toString() => '${kind.name}($text)';
}

/// $x^2$ style math: no space right after the opening $ or right before the
/// closing one, so prices like "5 $ et 6 $" stay text.
final _dollar = RegExp(r'\$(?!\s)([^$\n]+?)(?<!\s)\$');

/// Splits \( \), \[ \], $$ $$ and $ $ math out of [t]. Never throws:
/// an unclosed \( or \[ runs to the end of the string, a stray \) or \] is
/// dropped, `inline code` is skipped (a $ inside code stays code).
List<MathPiece> splitMath(String t) {
  final out = <MathPiece>[];
  final n = t.length;
  var i = 0;
  var textStart = 0;
  void flush(int end) {
    if (end > textStart) {
      out.add(
        MathPiece(
          MathPieceKind.text,
          t.substring(textStart, end),
          textStart,
          end,
        ),
      );
    }
  }

  while (i < n) {
    final c = t[i];
    if (c == '`') {
      final close = t.indexOf('`', i + 1);
      final nl = t.indexOf('\n', i + 1);
      i = (close > 0 && (nl < 0 || close < nl)) ? close + 1 : i + 1;
      continue;
    }
    if (c == r'\' && i + 1 < n) {
      final d = t[i + 1];
      if (d == '(' || d == '[') {
        final close = t.indexOf(d == '(' ? r'\)' : r'\]', i + 2);
        final end = close < 0 ? n : close;
        flush(i);
        out.add(
          MathPiece(
            d == '(' ? MathPieceKind.inline : MathPieceKind.display,
            t.substring(i + 2, end),
            i,
            close < 0 ? n : close + 2,
          ),
        );
        i = close < 0 ? n : close + 2;
        textStart = i;
        continue;
      }
      if (d == ')' || d == ']') {
        flush(i);
        i += 2;
        textStart = i;
        continue;
      }
      i += 2;
      continue;
    }
    if (c == r'$') {
      if (i + 1 < n && t[i + 1] == r'$') {
        final close = t.indexOf(r'$$', i + 2);
        if (close >= 0) {
          flush(i);
          out.add(
            MathPiece(
              MathPieceKind.display,
              t.substring(i + 2, close),
              i,
              close + 2,
            ),
          );
          i = close + 2;
          textStart = i;
          continue;
        }
        i += 2;
        continue;
      }
      final m = _dollar.matchAsPrefix(t, i);
      if (m != null) {
        flush(i);
        out.add(MathPiece(MathPieceKind.inline, m.group(1) ?? '', i, m.end));
        i = m.end;
        textStart = i;
        continue;
      }
    }
    i++;
  }
  flush(n);
  return out;
}

/// Text chunks and display formulas, in order. A string without display
/// math comes back as ONE untouched chunk.
List<({bool display, String text})> splitDisplayMath(String t) {
  final pieces = splitMath(t);
  if (!pieces.any((p) => p.kind == MathPieceKind.display)) {
    return [(display: false, text: t)];
  }
  final out = <({bool display, String text})>[];
  var from = 0;
  for (final p in pieces) {
    if (p.kind != MathPieceKind.display) continue;
    final before = t.substring(from, p.start).trim();
    if (before.isNotEmpty) out.add((display: false, text: before));
    if (p.text.trim().isNotEmpty) out.add((display: true, text: p.text.trim()));
    from = p.end;
  }
  final rest = t.substring(from).trim();
  if (rest.isNotEmpty) out.add((display: false, text: rest));
  return out;
}

final _doubleEscapedHint = RegExp(r'\\\\(\(|\[|[a-zA-Z]{2,})');
final _doubleEscaped = RegExp(r'\\\\(?=[a-zA-Z()\[\]{},;:!])');

/// Strings that arrived double-escaped ("\\frac", "\\(") are fixed once.
/// A real LaTeX line break "\\ " (followed by a space) is kept.
String normalizeLatexEscapes(String s) {
  if (!s.contains(r'\\') || !_doubleEscapedHint.hasMatch(s)) return s;
  return s.replaceAll(_doubleEscaped, r'\');
}

/// True when [s] holds something MathText must draw specially.
bool mayContainMath(String s) =>
    s.contains(r'\') || s.contains(r'$') || s.contains('`');

/// True when an SVG / native text looks like LaTeX (delimiters, commands,
/// ^{ } or _{ }).
bool looksLikeLatex(String s) =>
    s.contains(r'\(') ||
    s.contains(r'\[') ||
    _dollar.hasMatch(s) ||
    RegExp(r'\\[a-zA-Z]+').hasMatch(s) ||
    RegExp(r'[\^_]\{').hasMatch(s);

final _fence = RegExp(r'```[\w+#.-]*[ \t]*\n?([\s\S]*?)```');
final _inlineCode = RegExp(r'`([^`\n]+)`');
final _bareCommand = RegExp(r'\\([a-zA-Z]+)');

/// Readable Unicode for a whole content string (any delimiters, code
/// fences, inline code). Example: "On pose \(x = 2\pi\)" -> "On pose x = 2 pi" (with the Greek letter).
String latexToPlain(String text) {
  var t = normalizeLatexEscapes(text);
  t = t.replaceAllMapped(_fence, (m) => (m.group(1) ?? '').trimRight());
  final b = StringBuffer();
  for (final p in splitMath(t)) {
    if (p.isMath) {
      b.write(mathToPlain(p.text));
    } else {
      var s = p.text.replaceAllMapped(_inlineCode, (m) => m.group(1) ?? '');
      if (_bareCommand.hasMatch(s)) s = mathToPlain(s);
      b.write(s.replaceAll('{,}', ','));
    }
  }
  return _tidy(b.toString());
}

/// Only known symbol commands in ordinary text (\pi -> Greek pi, \$ -> $); braces,
/// ^ and _ are left alone. Safe for prose.
String fixBareCommands(String s) {
  if (!s.contains(r'\')) return s;
  return s.replaceAll(r'\$', r'$').replaceAllMapped(_bareCommand, (m) {
    final name = m.group(1)!;
    return _symbols[name] ?? (_functions.contains(name) ? name : m[0]!);
  });
}

/// Readable Unicode for one formula (no delimiters).
String mathToPlain(String latex) =>
    _tidy(_Conv(normalizeLatexEscapes(latex)).run());

String _tidy(String s) => s
    .replaceAll(RegExp(r'[ \t\u00A0]{2,}'), ' ')
    .replaceAll(RegExp(r' *\n *'), '\n')
    .trim();

class _Conv {
  _Conv(this.s);

  final String s;
  int i = 0;

  String run() {
    final b = StringBuffer();
    while (i < s.length) {
      final c = s[i];
      if (c == r'\') {
        b.write(_command());
      } else if (c == '{') {
        b.write(_Conv(_group()).run());
      } else if (c == '}') {
        i++;
      } else if (c == '^' || c == '_') {
        i++;
        final arg = _Conv(_arg()).run().trim();
        b.write(c == '^' ? _sup(arg) : _sub(arg));
      } else if (c == '~' || c == '&') {
        b.write(' ');
        i++;
      } else {
        b.write(c);
        i++;
      }
    }
    return b.toString();
  }

  /// s[i] == '{': returns the inside of the balanced group, moves past it.
  String _group() {
    final start = i + 1;
    var depth = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          i++;
          return s.substring(start, i - 1);
        }
      }
      i++;
    }
    i = s.length;
    return start <= s.length ? s.substring(start) : '';
  }

  /// One argument: {group}, \command or a single character (raw source).
  String _arg() {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
    if (i >= s.length) return '';
    if (s[i] == '{') return _group();
    if (s[i] == r'\') {
      final start = i;
      i++;
      if (i < s.length && _isLetter(s[i])) {
        while (i < s.length && _isLetter(s[i])) {
          i++;
        }
      } else if (i < s.length) {
        i++;
      }
      return s.substring(start, i);
    }
    return s[i++];
  }

  String _conv(String raw) => _Conv(raw).run().trim();

  String _command() {
    i++;
    if (i >= s.length) return '';
    if (!_isLetter(s[i])) {
      final ch = s[i++];
      return switch (ch) {
        ',' || ';' || ':' || '>' || ' ' || r'\' => ' ',
        '!' || '(' || ')' || '[' || ']' => '',
        '|' => '\u2016',
        _ => ch,
      };
    }
    final start = i;
    while (i < s.length && _isLetter(s[i])) {
      i++;
    }
    final name = s.substring(start, i);
    switch (name) {
      case 'frac' || 'dfrac' || 'tfrac' || 'cfrac':
        {
          final a = _conv(_arg());
          final b = _conv(_arg());
          return '${_wrap(a)}/${_wrap(b)}';
        }
      case 'binom' || 'dbinom' || 'tbinom':
        {
          final a = _conv(_arg());
          final b = _conv(_arg());
          return 'C($a, $b)';
        }
      case 'sqrt':
        {
          var root = '';
          if (i < s.length && s[i] == '[') {
            final close = s.indexOf(']', i);
            if (close > i) {
              root = _conv(s.substring(i + 1, close));
              i = close + 1;
            }
          }
          final x = _wrap(_conv(_arg()));
          return switch (root) {
            '' => '\u221A$x',
            '3' => '\u221B$x',
            '4' => '\u221C$x',
            _ => '${_sup(root)}\u221A$x',
          };
        }
      case 'text' ||
          'textrm' ||
          'textit' ||
          'textbf' ||
          'textsf' ||
          'texttt' ||
          'textnormal' ||
          'mathrm' ||
          'mathit' ||
          'mathbf' ||
          'mathsf' ||
          'mathtt' ||
          'mathcal' ||
          'mathscr' ||
          'mathfrak' ||
          'operatorname' ||
          'mbox' ||
          'boldsymbol' ||
          'bm' ||
          'emph' ||
          'ce':
        {
          return _Conv(_arg()).run();
        }
      case 'mathbb':
        {
          final x = _conv(_arg());
          return _blackboard[x] ?? x;
        }
      case 'vec' || 'overrightarrow':
        {
          return _accent(_conv(_arg()), '\u20D7');
        }
      case 'dot':
        {
          return _accent(_conv(_arg()), '\u0307');
        }
      case 'ddot':
        {
          return _accent(_conv(_arg()), '\u0308');
        }
      case 'hat' || 'widehat':
        {
          return _accent(_conv(_arg()), '\u0302');
        }
      case 'tilde' || 'widetilde':
        {
          return _accent(_conv(_arg()), '\u0303');
        }
      case 'bar':
        {
          return _accent(_conv(_arg()), '\u0304');
        }
      case 'overline':
        {
          return _conv(_arg()).split('').map((c) => '$c\u0305').join();
        }
      case 'underline':
        {
          return _conv(_arg()).split('').map((c) => '$c\u0332').join();
        }
      case 'left' || 'right':
        {
          if (i < s.length && s[i] == '.') i++;
          return '';
        }
      case 'begin':
        {
          final env = _arg();
          if (env == 'array' && i < s.length && s[i] == '{') _group();
          return '';
        }
      case 'end':
        {
          _arg();
          return '';
        }
      case 'not':
        {
          if (i < s.length && s[i] == '=') {
            i++;
            return '\u2260';
          }
          return '';
        }
      case 'overset' || 'underset' || 'stackrel':
        {
          _arg();
          return _conv(_arg());
        }
      case 'xrightarrow' || 'xleftarrow':
        {
          if (i < s.length && s[i] == '[') {
            final close = s.indexOf(']', i);
            if (close > i) i = close + 1;
          }
          _arg();
          return name == 'xrightarrow' ? '\u2192' : '\u2190';
        }
      case 'textcolor':
        {
          _arg();
          return _Conv(_arg()).run();
        }
      case 'color' || 'hspace' || 'vspace' || 'phantom' || 'label' || 'tag':
        {
          _arg();
          return name == 'hspace' ? ' ' : '';
        }
      case 'pmod':
        {
          return ' (mod ${_conv(_arg())})';
        }
    }
    if (_ignored.contains(name)) return '';
    final sym = _symbols[name];
    if (sym != null) return sym;
    return name;
  }
}

bool _isLetter(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
}

String _accent(String x, String mark) => x.isEmpty ? '' : '$x$mark';

final _complex = RegExp(
  r'[ +\-\u2212=<>/\u00B7\u00D7\u00B1\u2264\u2265\u2248\u223C\u2192,]',
);

String _wrap(String x) {
  if (x.isEmpty) return x;
  if (x.startsWith('(') && x.endsWith(')')) return x;
  return _complex.hasMatch(x) ? '($x)' : x;
}

String _sup(String x) {
  if (x.isEmpty) return '';
  if (x == '\u2218') return '\u00B0';
  final t = x.replaceAll(' ', '');
  if (t.split('').every(_supMap.containsKey)) {
    return t.split('').map((c) => _supMap[c]).join();
  }
  return t.length == 1 ? '^$t' : '^($t)';
}

String _sub(String x) {
  if (x.isEmpty) return '';
  final t = x.replaceAll(' ', '');
  if (t.split('').every(_subMap.containsKey)) {
    return t.split('').map((c) => _subMap[c]).join();
  }
  return t.length == 1 ? '_$t' : '_($t)';
}

const _supMap = {
  '0': '\u2070',
  '1': '\u00B9',
  '2': '\u00B2',
  '3': '\u00B3',
  '4': '\u2074',
  '5': '\u2075',
  '6': '\u2076',
  '7': '\u2077',
  '8': '\u2078',
  '9': '\u2079',
  '+': '\u207A',
  '-': '\u207B',
  '\u2212': '\u207B',
  '=': '\u207C',
  '(': '\u207D',
  ')': '\u207E',
  'a': '\u1D43',
  'b': '\u1D47',
  'c': '\u1D9C',
  'd': '\u1D48',
  'e': '\u1D49',
  'f': '\u1DA0',
  'g': '\u1D4D',
  'h': '\u02B0',
  'i': '\u2071',
  'j': '\u02B2',
  'k': '\u1D4F',
  'l': '\u02E1',
  'm': '\u1D50',
  'n': '\u207F',
  'o': '\u1D52',
  'p': '\u1D56',
  'r': '\u02B3',
  's': '\u02E2',
  't': '\u1D57',
  'u': '\u1D58',
  'v': '\u1D5B',
  'w': '\u02B7',
  'x': '\u02E3',
  'y': '\u02B8',
  'z': '\u1DBB',
  'T': '\u1D40',
  '\u2032': '\u2032',
  '*': '*',
};

const _subMap = {
  '0': '\u2080',
  '1': '\u2081',
  '2': '\u2082',
  '3': '\u2083',
  '4': '\u2084',
  '5': '\u2085',
  '6': '\u2086',
  '7': '\u2087',
  '8': '\u2088',
  '9': '\u2089',
  '+': '\u208A',
  '-': '\u208B',
  '\u2212': '\u208B',
  '=': '\u208C',
  '(': '\u208D',
  ')': '\u208E',
  'a': '\u2090',
  'e': '\u2091',
  'h': '\u2095',
  'i': '\u1D62',
  'j': '\u2C7C',
  'k': '\u2096',
  'l': '\u2097',
  'm': '\u2098',
  'n': '\u2099',
  'o': '\u2092',
  'p': '\u209A',
  'r': '\u1D63',
  's': '\u209B',
  't': '\u209C',
  'u': '\u1D64',
  'v': '\u1D65',
  'x': '\u2093',
  '\u03B2': '\u1D66',
  '\u03B3': '\u1D67',
  '\u03C1': '\u1D68',
  '\u03C6': '\u1D69',
  '\u03C7': '\u1D6A',
};

const _blackboard = {
  'R': '\u211D',
  'N': '\u2115',
  'Z': '\u2124',
  'Q': '\u211A',
  'C': '\u2102',
  'E': '\u{1D53C}',
  'P': '\u2119',
};

const _ignored = {
  'displaystyle',
  'textstyle',
  'scriptstyle',
  'limits',
  'nolimits',
  'big',
  'Big',
  'bigg',
  'Bigg',
  'bigl',
  'bigr',
  'Bigl',
  'Bigr',
  'biggl',
  'biggr',
  'mathstrut',
  'strut',
  'middle',
  'nonumber',
  'notag',
};

const _functions = {
  'sin',
  'cos',
  'tan',
  'cot',
  'sec',
  'csc',
  'arcsin',
  'arccos',
  'arctan',
  'sinh',
  'cosh',
  'tanh',
  'ln',
  'log',
  'exp',
  'lim',
  'max',
  'min',
  'sup',
  'inf',
  'det',
  'deg',
  'dim',
  'ker',
  'gcd',
  'arg',
  'mod',
  'Pr',
  'th',
  'sh',
  'ch',
};

const _symbols = <String, String>{
  // Greek
  'alpha': '\u03B1',
  'beta': '\u03B2',
  'gamma': '\u03B3',
  'delta': '\u03B4',
  'epsilon': '\u03B5',
  'varepsilon': '\u03B5',
  'zeta': '\u03B6',
  'eta': '\u03B7',
  'theta': '\u03B8',
  'vartheta': '\u03D1',
  'iota': '\u03B9',
  'kappa': '\u03BA',
  'lambda': '\u03BB',
  'mu': '\u03BC',
  'nu': '\u03BD',
  'xi': '\u03BE',
  'pi': '\u03C0',
  'varpi': '\u03D6',
  'rho': '\u03C1',
  'varrho': '\u03F1',
  'sigma': '\u03C3',
  'varsigma': '\u03C2',
  'tau': '\u03C4',
  'upsilon': '\u03C5',
  'phi': '\u03C6',
  'varphi': '\u03C6',
  'chi': '\u03C7',
  'psi': '\u03C8',
  'omega': '\u03C9',
  'Gamma': '\u0393',
  'Delta': '\u0394',
  'Theta': '\u0398',
  'Lambda': '\u039B',
  'Xi': '\u039E',
  'Pi': '\u03A0',
  'Sigma': '\u03A3',
  'Upsilon': '\u03A5', 'Phi': '\u03A6', 'Psi': '\u03A8', 'Omega': '\u03A9',
  // Relations and arrows
  'leq': '\u2264',
  'le': '\u2264',
  'leqslant': '\u2264',
  'geq': '\u2265',
  'ge': '\u2265',
  'geqslant': '\u2265',
  'neq': '\u2260',
  'ne': '\u2260',
  'approx': '\u2248',
  'sim': '\u223C',
  'simeq': '\u2243',
  'cong': '\u2245',
  'equiv': '\u2261',
  'propto': '\u221D',
  'll': '\u226A',
  'gg': '\u226B',
  'to': '\u2192',
  'rightarrow': '\u2192',
  'longrightarrow': '\u27F6',
  'leftarrow': '\u2190',
  'gets': '\u2190',
  'longleftarrow': '\u27F5',
  'Rightarrow': '\u21D2',
  'implies': '\u21D2',
  'Leftarrow': '\u21D0',
  'Leftrightarrow': '\u21D4',
  'iff': '\u21D4',
  'leftrightarrow': '\u2194', 'rightleftharpoons': '\u21CC', 'mapsto': '\u21A6',
  'uparrow': '\u2191',
  'downarrow': '\u2193',
  'perp': '\u22A5',
  'parallel': '\u2225',
  'mid': '|', 'vert': '|', 'Vert': '\u2016',
  // Operators
  'times': '\u00D7',
  'cdot': '\u00B7',
  'div': '\u00F7',
  'pm': '\u00B1',
  'mp': '\u2213',
  'ast': '\u2217',
  'star': '\u22C6',
  'circ': '\u2218',
  'bullet': '\u2022',
  'oplus': '\u2295',
  'otimes': '\u2297',
  'sum': '\u2211',
  'prod': '\u220F',
  'int': '\u222B',
  'iint': '\u222C',
  'iiint': '\u222D',
  'oint': '\u222E', 'partial': '\u2202', 'nabla': '\u2207', 'infty': '\u221E',
  // Logic and sets
  'forall': '\u2200',
  'exists': '\u2203',
  'nexists': '\u2204',
  'neg': '\u00AC',
  'lnot': '\u00AC',
  'land': '\u2227',
  'wedge': '\u2227',
  'lor': '\u2228',
  'vee': '\u2228',
  'in': '\u2208',
  'notin': '\u2209',
  'ni': '\u220B',
  'subset': '\u2282',
  'subseteq': '\u2286',
  'supset': '\u2283',
  'supseteq': '\u2287', 'cup': '\u222A', 'cap': '\u2229', 'setminus': '\u2216',
  'emptyset': '\u2205', 'varnothing': '\u2205',
  // Misc
  'ldots': '\u2026',
  'dots': '\u2026',
  'cdots': '\u22EF',
  'vdots': '\u22EE',
  'ddots': '\u22F1',
  'langle': '\u27E8',
  'rangle': '\u27E9',
  'lfloor': '\u230A',
  'rfloor': '\u230B',
  'lceil': '\u2308',
  'rceil': '\u2309',
  'angle': '\u2220',
  'degree': '\u00B0',
  'prime': '\u2032',
  'hbar': '\u210F',
  'ell': '\u2113',
  'Re': '\u211C',
  'Im': '\u2111',
  'aleph': '\u2135',
  'quad': ' ', 'qquad': ' ', 'backslash': r'\', 'lbrace': '{',
  'rbrace': '}', 'surd': '\u221A', 'triangle': '\u25B3', 'square': '\u25A1',
  'therefore': '\u2234',
  'because': '\u2235',
  'checkmark': '\u2713',
  'AA': '\u00C5',
  'ohm': '\u03A9', 'micro': '\u00B5', 'celsius': '\u00B0C',
};
