import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'block_style.dart';
import 'math_view.dart';
import 'rich_block_text.dart';

List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];

/// A text in the lesson language: plain strings, numbers, lists (one per
/// line) and {en, fr, ar} maps are all accepted.
String tableText(Object? v, String lang) {
  if (v == null) return '';
  if (v is List) return v.map((e) => tableText(e, lang)).join('\n');
  if (v is Map) {
    if (v.containsKey('value') || v.containsKey('latex')) {
      return tableText(v['value'] ?? v['latex'], lang);
    }
    final t =
        v[lang] ?? v['fr'] ?? v['en'] ?? (v.isEmpty ? null : v.values.first);
    return tableText(t, lang);
  }
  return '$v';
}

final _latexHint = RegExp(r'\\[A-Za-z]+|[_^]\{|[_^][0-9A-Za-z]');

/// A cell value that is raw LaTeX without \( \) delimiters (e.g.
/// "\mathrm{Fe_2O_3}" or "10^{-3}").
bool looksLikeLatex(String s) =>
    s.isNotEmpty && !s.contains(r'\(') && _latexHint.hasMatch(s);

/// One table cell, whatever shape the content uses: a plain string, or
/// {value, unit?, note?, latex?}.
class TableCellData {
  const TableCellData({
    this.value = '',
    this.unit = '',
    this.note = '',
    this.latex = '',
  });

  factory TableCellData.from(Object? raw, String lang) {
    const fields = {
      'value',
      'text',
      'content',
      'label',
      'latex',
      'unit',
      'note',
    };
    if (raw is Map && raw.keys.any(fields.contains)) {
      return TableCellData._dollars(
        value: tableText(
          raw['value'] ?? raw['text'] ?? raw['content'] ?? raw['label'],
          lang,
        ),
        unit: tableText(raw['unit'], lang),
        note: tableText(raw['note'], lang),
        latex: tableText(raw['latex'], lang),
      );
    }
    return TableCellData._dollars(value: tableText(raw, lang));
  }

  /// A whole value written as $...$ (or $$...$$) is a formula.
  factory TableCellData._dollars({
    String value = '',
    String unit = '',
    String note = '',
    String latex = '',
  }) {
    final m = RegExp(r'^\$\$?([^$]+?)\$\$?$').firstMatch(value.trim());
    if (m != null && latex.isEmpty) {
      return TableCellData(latex: m.group(1)!.trim(), unit: unit, note: note);
    }
    return TableCellData(value: value, unit: unit, note: note, latex: latex);
  }

  final String value;
  final String unit;
  final String note;
  final String latex;

  bool get isEmpty =>
      value.isEmpty && unit.isEmpty && note.isEmpty && latex.isEmpty;
}

/// The cells of a row: `cells` (or `values`), strings or maps.
List<TableCellData> rowCells(Map row, String lang) => [
  for (final c in _list(row['cells'] ?? row['values']))
    TableCellData.from(c, lang),
];

/// Readable text of a LaTeX string, only to estimate its width.
String latexPlain(String latex) => latex
    .replaceAll(RegExp(r'\\[A-Za-z]+'), '')
    .replaceAll(RegExp(r'[{}_^\\]'), '')
    .replaceAll(r'\(', '')
    .replaceAll(r'\)', '');

/// The text a cell shows, for measuring its column.
String cellPlain(TableCellData d) => [
  if (d.latex.isNotEmpty) latexPlain(d.latex),
  if (d.value.isNotEmpty)
    looksLikeLatex(d.value) || d.value.contains(r'\(')
        ? latexPlain(d.value)
        : d.value,
  if (d.unit.isNotEmpty) d.unit,
].join(' ');

double _measure(String text, TextStyle style, TextScaler scaler) {
  var w = 0.0;
  for (final line in text.split('\n')) {
    final tp = TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    w = math.max(w, tp.width);
    tp.dispose();
  }
  return w;
}

/// CONTENT_FORMAT 5.7: scrolls sideways, units after values, small cell
/// notes, footnotes under the table; columns mirror in Arabic. Cells show
/// LaTeX (a `latex` field, raw LaTeX or inline \( \)) and highlights.
class TableBlock extends StatelessWidget {
  const TableBlock({super.key, required this.block, required this.style});

  final Map<String, dynamic> block;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    final lang = style.language;
    // Header cells: a string, a language map or {id, label, latex?, unit?}.
    final columns = [
      for (final c in _list(block['columns'])) TableCellData.from(c, lang),
    ];
    final rows = [
      for (final r in _list(block['rows']))
        if (r is Map) r,
    ];
    var count = columns.length;
    for (final r in rows) {
      final n = 1 + rowCells(r, lang).length;
      if (n > count) count = n;
    }
    final small = TextStyle(
      fontSize: 12 * style.scale,
      color: kc.textSecondary,
    );
    final cellStyle = BlockStyle(
      language: style.language,
      scale: style.scale * 0.875,
      kc: style.kc,
      labels: style.labels,
      base: style.base,
    );
    final mathStyle = style.body.copyWith(fontSize: 14 * style.scale);

    Widget content(TableCellData d, {bool bold = false}) {
      final parts = <Widget>[];
      if (d.latex.isNotEmpty) {
        parts.add(InlineMath(latex: d.latex, style: mathStyle));
      }
      if (d.value.isNotEmpty) {
        if (d.latex.isEmpty && looksLikeLatex(d.value)) {
          parts.add(InlineMath(latex: d.value, style: mathStyle));
        } else if (d.latex.isEmpty || d.value != d.latex) {
          parts.add(
            RichBlockText(
              text: d.value,
              style: bold
                  ? BlockStyle(
                      language: cellStyle.language,
                      scale: cellStyle.scale,
                      kc: cellStyle.kc,
                      labels: cellStyle.labels,
                      base: cellStyle.base.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : cellStyle,
            ),
          );
        }
      }
      if (d.unit.isNotEmpty) {
        parts.add(Text(style.ltr(d.unit), style: mathStyle));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.md,
          vertical: KSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (parts.isNotEmpty)
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: parts,
              ),
            if (d.note.isNotEmpty) Text(d.note, style: small),
          ],
        ),
      );
    }

    final scaler = MediaQuery.textScalerOf(context);
    final measureStyle = style.body.copyWith(fontSize: 14 * style.scale);
    final bold = measureStyle.copyWith(fontWeight: FontWeight.w700);
    final widths = List<double>.filled(count, 0);
    void grow(int i, TableCellData d, TextStyle st) {
      if (i >= count) return;
      final w = math.max(
        _measure(cellPlain(d), st, scaler),
        _measure(d.note, small, scaler),
      );
      widths[i] = math.max(widths[i], w);
    }

    for (var i = 0; i < columns.length; i++) {
      grow(i, columns[i], bold);
    }
    for (final r in rows) {
      grow(0, TableCellData.from(r['label'], lang), bold);
      final cells = rowCells(r, lang);
      for (var i = 0; i < cells.length; i++) {
        grow(i + 1, cells[i], measureStyle);
      }
    }
    for (var i = 0; i < count; i++) {
      widths[i] = math.min(
        300.0 * style.scale,
        math.max(72.0 * style.scale, widths[i] * 1.15 + KSpace.md * 2 + 8),
      );
    }
    List<Widget> fit(List<Widget> cells) => [
      for (var i = 0; i < count; i++)
        i < cells.length ? cells[i] : const SizedBox.shrink(),
    ];
    final label = tableText(block['table_label'], lang);
    final caption = tableText(block['caption'], lang);
    final footnotes = tableText(block['footnotes'], lang);
    final title = [label, caption].where((s) => s.isNotEmpty).join(' \u00b7 ');
    if (count == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.sm),
            child: Text(
              title,
              style: style.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            // Fixed widths measured from the text: math cells cannot be
            // asked for an intrinsic width.
            columnWidths: {
              for (var i = 0; i < count; i++) i: FixedColumnWidth(widths[i]),
            },
            border: TableBorder.all(
              color: kc.border,
              borderRadius: BorderRadius.circular(8),
            ),
            children: [
              if (columns.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(color: kc.surfaceRaised),
                  children: fit([
                    for (final c in columns) content(c, bold: true),
                  ]),
                ),
              for (final r in rows)
                TableRow(
                  children: fit([
                    content(TableCellData.from(r['label'], lang), bold: true),
                    for (final c in rowCells(r, lang)) content(c),
                  ]),
                ),
            ],
          ),
        ),
        if (footnotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.xs),
            child: Text(footnotes, style: small),
          ),
      ],
    );
  }
}
