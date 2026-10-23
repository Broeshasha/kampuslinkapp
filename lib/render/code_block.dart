import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tokens.dart';
import '../data/lessons/figures.dart' show figureText;
import '../l10n/app_localizations.dart';
import 'block_style.dart';
import 'code_tokens.dart';
import 'figure_block.dart' show svgPalette;
import 'rich_block_text.dart';

const codeFontFamily = 'monospace';
const codeFontFallback = ['RobotoMono', 'Menlo', 'Consolas', 'Courier New'];

String _s(Object? v) => v == null ? '' : '$v';

/// One annotation: a numbered note attached to a line of the code.
class CodeNote {
  const CodeNote(this.line, this.text);

  final int line;
  final String text;
}

/// Lesson block type "code" (WP16 C). Fields read leniently:
/// code | content | source, language, output | result, title | caption,
/// annotations: [{line, text | note | content}] (text may be per language).
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    required this.style,
    this.language = '',
    this.output = '',
    this.title = '',
    this.notes = const [],
  });

  factory CodeBlock.fromBlock(Map<String, dynamic> block, BlockStyle style) {
    final raw = block['annotations'] ?? block['notes'];
    final notes = <CodeNote>[
      if (raw is List)
        for (final a in raw)
          if (a is Map && a['line'] is num)
            CodeNote(
              (a['line'] as num).toInt(),
              figureText(
                a['text'] ?? a['note'] ?? a['content'],
                style.language,
              ),
            ),
    ];
    return CodeBlock(
      code: _s(block['code'] ?? block['content'] ?? block['source']),
      language: _s(block['language'] ?? block['lang']),
      output: _s(block['output'] ?? block['result']),
      title: figureText(block['title'] ?? block['caption'], style.language),
      notes: notes,
      style: style,
    );
  }

  final String code;
  final String language;
  final String output;
  final String title;
  final List<CodeNote> notes;
  final BlockStyle style;

  TextStyle get _mono => TextStyle(
    fontFamily: codeFontFamily,
    fontFamilyFallback: codeFontFallback,
    fontSize: 14 * style.scale,
    height: 1.45,
    color: style.kc.textPrimary,
  );

  Color _colour(CodeTokenKind kind) {
    final kc = style.kc;
    final p = svgPalette(kc);
    return switch (kind) {
      CodeTokenKind.keyword => p[1],
      CodeTokenKind.builtin => p[0],
      CodeTokenKind.string => p[5],
      CodeTokenKind.number => p[3],
      CodeTokenKind.comment => kc.textSecondary,
      CodeTokenKind.plain => kc.textPrimary,
    };
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = AppLocalizations.of(context).codeCopied;
    await Clipboard.setData(ClipboardData(text: code));
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _badge(int n, {double size = 18}) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: style.kc.accent, shape: BoxShape.circle),
    child: Text(
      '$n',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.6,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    final lines = code.split('\n');
    final mono = _mono;
    final gutter = mono.copyWith(color: kc.textSecondary);
    final digits = '${lines.length}'.length;
    final badges = <int, List<int>>{};
    for (var i = 0; i < notes.length; i++) {
      badges.putIfAbsent(notes[i].line, () => []).add(i + 1);
    }
    final label = language.isEmpty ? '' : language.toUpperCase();
    final codeView = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(0, KSpace.sm, KSpace.md, KSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: (digits + 2) * 9.0 * style.scale,
                  padding: const EdgeInsetsDirectional.only(end: KSpace.sm),
                  alignment: AlignmentDirectional.topEnd,
                  child: ExcludeSemantics(
                    child: Text('${i + 1}', style: gutter),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    style: mono,
                    children: [
                      for (final t in tokenizeLine(lines[i]))
                        TextSpan(
                          text: t.text,
                          style: TextStyle(
                            color: _colour(t.kind),
                            fontStyle: t.kind == CodeTokenKind.comment
                                ? FontStyle.italic
                                : null,
                            fontWeight: t.kind == CodeTokenKind.keyword
                                ? FontWeight.w700
                                : null,
                          ),
                        ),
                      for (final n in badges[i + 1] ?? const <int>[])
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: KSpace.sm,
                            ),
                            child: _badge(n),
                          ),
                        ),
                    ],
                  ),
                  softWrap: false,
                ),
              ],
            ),
        ],
      ),
    );
    final box = Container(
      key: const ValueKey('code-block'),
      decoration: BoxDecoration(
        color: kc.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.chip),
        border: Border.all(color: kc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpace.md,
              KSpace.xs,
              KSpace.xs,
              0,
            ),
            child: Row(
              children: [
                Icon(Icons.code_rounded, size: 18, color: kc.accentText),
                const SizedBox(width: KSpace.xs),
                Expanded(
                  child: Text(
                    [label, title].where((s) => s.isNotEmpty).join(' \u00b7 '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: kc.textSecondary,
                      fontSize: 12 * style.scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).codeCopy,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: kc.textPrimary,
                  ),
                  onPressed: () => _copy(context),
                ),
              ],
            ),
          ),
          codeView,
          if (output.isNotEmpty)
            Container(
              key: const ValueKey('code-result'),
              color: kc.background,
              padding: const EdgeInsets.all(KSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.labels.codeResult,
                    style: TextStyle(
                      color: kc.success,
                      fontSize: 12 * style.scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: KSpace.xs),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(output, style: mono, softWrap: false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Code is always left-to-right, even in an Arabic lesson.
        Directionality(textDirection: TextDirection.ltr, child: box),
        for (var i = 0; i < notes.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _badge(i + 1, size: 20),
                ),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: RichBlockText(text: notes[i].text, style: style),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
