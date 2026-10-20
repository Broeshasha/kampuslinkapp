import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'block_style.dart';

List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
String _text(Object? v) => v == null ? '' : (v is List ? v.join('\n') : '$v');

/// CONTENT_FORMAT 5.7: scrolls sideways, units after values, small cell
/// notes, footnotes under the table; columns mirror in Arabic.
class TableBlock extends StatelessWidget {
  const TableBlock({super.key, required this.block, required this.style});

  final Map<String, dynamic> block;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    final columns = _list(block['columns']).map(_map).toList();
    final rows = _list(block['rows']).map(_map).toList();
    final count = columns.isNotEmpty
        ? columns.length
        : 1 + (rows.isEmpty ? 0 : _list(rows.first['cells']).length);
    final small = TextStyle(
      fontSize: 12 * style.scale,
      color: kc.textSecondary,
    );
    Widget cell(String text, {bool bold = false, String? note}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.md,
        vertical: KSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: style.body.copyWith(
              fontSize: 14 * style.scale,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (note != null && note.isNotEmpty) Text(note, style: small),
        ],
      ),
    );
    List<Widget> fit(List<Widget> cells) => [
      for (var i = 0; i < count; i++)
        i < cells.length ? cells[i] : const SizedBox.shrink(),
    ];
    final label = _text(block['table_label']);
    final caption = _text(block['caption']);
    final footnotes = _text(block['footnotes']);
    final title = [label, caption].where((s) => s.isNotEmpty).join(' \u00b7 ');
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
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(
              color: kc.border,
              borderRadius: BorderRadius.circular(8),
            ),
            children: [
              if (columns.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(color: kc.surfaceRaised),
                  children: fit([
                    for (final c in columns)
                      cell(_text(c['label']), bold: true),
                  ]),
                ),
              for (final r in rows)
                TableRow(
                  children: fit([
                    cell(_text(r['label']), bold: true),
                    for (final c in _list(r['cells']).map(_map))
                      cell(
                        style.ltr(
                          [
                            _text(c['value']),
                            if (c['unit'] != null) _text(c['unit']),
                          ].join(' '),
                        ),
                        note: c['note'] == null ? null : _text(c['note']),
                      ),
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
