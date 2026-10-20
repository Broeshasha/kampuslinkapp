/// CONTENT_FORMAT 5.3: split a text into plain / highlighted / inline-math
/// segments. Inline math \( ... \) is cut out first; highlights are placed
/// longest first, first free occurrence, never overlapping; a highlight whose
/// text is not found is ignored.
enum SegmentKind { plain, term, value, formula, warning, math }

class TextSegment {
  const TextSegment(this.text, this.kind);

  final String text;
  final SegmentKind kind;

  @override
  bool operator ==(Object other) =>
      other is TextSegment && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => '${kind.name}($text)';
}

SegmentKind _kindOf(String? kind) => switch (kind) {
  'term' => SegmentKind.term,
  'value' => SegmentKind.value,
  'formula' => SegmentKind.formula,
  'warning' => SegmentKind.warning,
  _ => SegmentKind.plain,
};

final _inlineMath = RegExp(r'\\\((.+?)\\\)');

List<TextSegment> segmentText(String text, List<Object?> highlights) {
  final ranges = <({int start, int end, SegmentKind kind, String text})>[];
  for (final m in _inlineMath.allMatches(text)) {
    ranges.add((
      start: m.start,
      end: m.end,
      kind: SegmentKind.math,
      text: m.group(1) ?? '',
    ));
  }
  bool overlaps(int s, int e) => ranges.any((r) => s < r.end && e > r.start);
  final wanted = [
    for (final h in highlights)
      if (h is Map && h['text'] is String && (h['text'] as String).isNotEmpty)
        (text: h['text'] as String, kind: _kindOf(h['kind']?.toString())),
  ]..sort((a, b) => b.text.length.compareTo(a.text.length));
  for (final h in wanted) {
    var from = 0;
    while (true) {
      final i = text.indexOf(h.text, from);
      if (i < 0) break;
      final e = i + h.text.length;
      if (!overlaps(i, e)) {
        ranges.add((start: i, end: e, kind: h.kind, text: h.text));
        break;
      }
      from = i + 1;
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final out = <TextSegment>[];
  var pos = 0;
  for (final r in ranges) {
    if (r.start > pos) {
      out.add(TextSegment(text.substring(pos, r.start), SegmentKind.plain));
    }
    out.add(TextSegment(r.text, r.kind));
    pos = r.end;
  }
  if (pos < text.length) {
    out.add(TextSegment(text.substring(pos), SegmentKind.plain));
  }
  return out;
}
