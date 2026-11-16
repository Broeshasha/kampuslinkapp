/// Bac content writes a lot of math WITHOUT delimiters: "e^{−x}", "10^-4",
/// "(z₁/z₂)^2008", "lim_{x→0⁺}", "e^(-t/τ)". Shown as text, the student sees
/// raw carets and braces. This pass finds those tokens and wraps them in
/// \( \) (as LaTeX) so the normal math renderer draws real powers and
/// indices. Text already using \( \) or $ $, code, and Arabic words are
/// never touched. A whole string that is raw LaTeX ("N_0\, e^{-\lambda t}")
/// with no Arabic is wrapped as one formula.
library;

import 'latex_plain.dart';

final _arabic = RegExp(
  r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]',
);
final _baseCh = RegExp(
  "[A-Za-z0-9.′'_∫₀-₉ₙ⁰-⁹²³¹"
  "αβγδΔεθλμπρσ"
  "φωΩτ|]",
);
final _expCh = RegExp("[A-Za-z0-9.′']");
final _rawCommand = RegExp(r'\\[A-Za-z]+');
final _trigger = RegExp(r'\^|_\{');
final _functions = RegExp(r'(?<![A-Za-z\\])(ln|log|sin|cos|tan|exp|lim)(?![A-Za-z])');

const _sub = {
  '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
  '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
  'ₙ': 'n',
};
const _sup = {
  '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
  '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
  '⁺': '+', '⁻': '-', 'ˣ': 'x', 'ⁿ': 'n', 'ᵃ': 'a',
  'ᵇ': 'b',
};
const _commands = {
  '−': '-', '×': r'\times ', '·': r'\cdot ', '′': "'",
  '∞': r'\infty ', '→': r'\to ', '↦': r'\mapsto ',
  '≤': r'\le ', '≥': r'\ge ', '≠': r'\ne ', '∫': r'\int ',
  'α': r'\alpha ', 'β': r'\beta ', 'γ': r'\gamma ',
  'δ': r'\delta ', 'Δ': r'\Delta ', 'ε': r'\varepsilon ',
  'θ': r'\theta ', 'λ': r'\lambda ', 'μ': r'\mu ',
  'π': r'\pi ', 'ρ': r'\rho ', 'σ': r'\sigma ',
  'φ': r'\varphi ', 'ω': r'\omega ', 'Ω': r'\Omega ',
  'τ': r'\tau ', 'ℂ': r'\mathbb{C}', 'ℝ': r'\mathbb{R}',
  '%': r'\%',
};

int _matchForward(String t, int i, String open, String close) {
  var depth = 0;
  for (var j = i; j < t.length; j++) {
    if (t[j] == open) {
      depth++;
    } else if (t[j] == close) {
      depth--;
      if (depth == 0) return j + 1;
    }
  }
  return -1;
}

int _matchBack(String t, int i, String open, String close) {
  var depth = 0;
  for (var j = i; j >= 0; j--) {
    if (t[j] == close) {
      depth++;
    } else if (t[j] == open) {
      depth--;
      if (depth == 0) return j;
    }
  }
  return -1;
}

/// [start, end) of the bare formula around the ^ or _{ at [k], or null.
(int, int)? _token(String t, int k) {
  final j = k + 1;
  if (j >= t.length) return null;
  int e;
  if (t[j] == '{' || t[j] == '(') {
    e = _matchForward(t, j, t[j], t[j] == '{' ? '}' : ')');
    if (e < 0) return null;
  } else {
    if (t[k] == '_') return null;
    e = j;
    if (e < t.length && '+-−'.contains(t[e])) e++;
    final s0 = e;
    while (e < t.length && _expCh.hasMatch(t[e])) {
      e++;
    }
    while (e > s0 && '.,'.contains(t[e - 1])) {
      e--;
    }
    if (e == s0) return null;
  }
  var s = k;
  while (s > 0) {
    final c = t[s - 1];
    if (c == ')' || c == ']') {
      final b = _matchBack(t, s - 1, c == ')' ? '(' : '[', c);
      if (b < 0) break;
      s = b;
      continue;
    }
    if (_baseCh.hasMatch(c)) {
      s--;
      continue;
    }
    break;
  }
  while (s < k && '.,'.contains(t[s])) {
    s++;
  }
  if (s == k) return null;
  if (_arabic.hasMatch(t.substring(s, e))) return null;
  return (s, e);
}

/// Bare formula text -> LaTeX.
String bareToLatex(String tok) {
  final out = StringBuffer();
  var i = 0;
  while (i < tok.length) {
    final c = tok[i];
    if (c == '^' && i + 1 < tok.length && tok[i + 1] == '(') {
      final e = _matchForward(tok, i + 1, '(', ')');
      if (e > 0) {
        out.write('^{${bareToLatex(tok.substring(i + 2, e - 1))}}');
        i = e;
        continue;
      }
    }
    if (c == '^' && i + 1 < tok.length && tok[i + 1] != '{') {
      var j = i + 1;
      if ('+-−'.contains(tok[j])) j++;
      while (j < tok.length && _expCh.hasMatch(tok[j])) {
        j++;
      }
      out.write('^{${bareToLatex(tok.substring(i + 1, j))}}');
      i = j;
      continue;
    }
    if (_sub.containsKey(c)) {
      final b = StringBuffer();
      while (i < tok.length && _sub.containsKey(tok[i])) {
        b.write(_sub[tok[i]]);
        i++;
      }
      out.write('_{$b}');
      continue;
    }
    if (_sup.containsKey(c)) {
      final b = StringBuffer();
      while (i < tok.length && _sup.containsKey(tok[i])) {
        b.write(_sup[tok[i]]);
        i++;
      }
      out.write('^{$b}');
      continue;
    }
    out.write(_commands[c] ?? c);
    i++;
  }
  return out.toString().replaceAllMapped(_functions, (m) => '\\${m[1]}');
}

String _wrapPiece(String t) {
  if (t.contains('`')) return t;
  if (_rawCommand.hasMatch(t)) {
    if (_arabic.hasMatch(t) || t.contains('\n')) return t;
    final body = t.trim();
    if (body.isEmpty) return t;
    final lead = t.substring(0, t.indexOf(body));
    final tail = t.substring(t.indexOf(body) + body.length);
    return '$lead\\($body\\)$tail';
  }
  final ranges = <List<int>>[];
  for (final m in _trigger.allMatches(t)) {
    final r = _token(t, m.start);
    if (r != null) ranges.add([r.$1, r.$2]);
  }
  if (ranges.isEmpty) return t;
  ranges.sort((a, b) => a[0].compareTo(b[0]));
  final merged = <List<int>>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r[0] <= merged.last[1]) {
      if (r[1] > merged.last[1]) merged.last[1] = r[1];
    } else {
      merged.add(r);
    }
  }
  final out = StringBuffer();
  var p = 0;
  for (final r in merged) {
    out
      ..write(t.substring(p, r[0]))
      ..write('\\(${bareToLatex(t.substring(r[0], r[1]))}\\)');
    p = r[1];
  }
  out.write(t.substring(p));
  return out.toString();
}

final _cache = <String, String>{};

/// [text] with its bare formulas wrapped in \( \). Same string back when
/// there is nothing to do (fast: no ^ and no _{ -> no work).
String wrapBareMath(String text) {
  if (!text.contains('^') && !text.contains('_{')) return text;
  final hit = _cache[text];
  if (hit != null) return hit;
  final out = StringBuffer();
  for (final p in splitMath(text)) {
    if (p.isMath) {
      out.write(text.substring(p.start, p.end));
    } else {
      out.write(_wrapPiece(p.text));
    }
  }
  final r = out.toString();
  if (_cache.length > 400) _cache.remove(_cache.keys.first);
  _cache[text] = r;
  return r;
}
