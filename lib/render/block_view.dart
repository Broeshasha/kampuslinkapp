import 'package:flutter/material.dart';

import '../core/logging/logger.dart';
import '../core/theme/tokens.dart';
import 'block_style.dart';
import 'figure_block.dart';
import 'math_view.dart';
import 'rich_block_text.dart';
import 'table_block.dart';

final _loggedUnknown = <String>{};

String _str(Object? v) => v == null ? '' : '$v';
List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

/// Registry: block type -> widget (CONTENT_FORMAT 4 + 5). Unknown fields
/// (origin, ...) are ignored; note_kind picks the note's look. Never throws:
/// an unknown type shows its text (if any) and is logged once.
class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.block, required this.style});

  final Map<String, dynamic> block;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    final type = _str(block['type']);
    final content = _str(block['content']);
    final highlights = _list(block['highlights']);
    Widget rich() =>
        RichBlockText(text: content, highlights: highlights, style: style);
    final formula = _map(block['formula']);
    final level = block['level'];
    final number = block['number'];
    return switch (type) {
      'heading' => _Heading(
        text: content,
        level: level is num ? level.toInt() : 2,
        style: style,
      ),
      'paragraph' => rich(),
      'definition' => _Callout(
        label: style.labels.blockDefinition,
        icon: Icons.menu_book_outlined,
        color: kc.accentText,
        style: style,
        child: rich(),
      ),
      'example' => _Callout(
        label: style.labels.blockExample,
        icon: Icons.lightbulb_outline,
        color: kc.success,
        style: style,
        child: rich(),
      ),
      'note' => switch (_str(block['note_kind'])) {
        'intuition' => _Callout(
          label: style.labels.noteIntuition,
          icon: Icons.emoji_objects_outlined,
          color: kc.accentAlt,
          style: style,
          child: rich(),
        ),
        'mistake' => _Callout(
          label: style.labels.noteMistake,
          icon: Icons.error_outline,
          color: kc.danger,
          style: style,
          child: rich(),
        ),
        'exam_tip' => _Callout(
          label: style.labels.noteExamTip,
          icon: Icons.school_outlined,
          color: kc.xp,
          style: style,
          child: rich(),
        ),
        'remember' => _Callout(
          label: style.labels.noteRemember,
          icon: Icons.push_pin_outlined,
          color: kc.accentText,
          style: style,
          child: rich(),
        ),
        _ => _Callout(
          label: style.labels.blockNote,
          icon: Icons.info_outline,
          color: kc.warning,
          style: style,
          child: rich(),
        ),
      },
      'application' => _Callout(
        label: style.labels.blockApplication,
        icon: Icons.construction_outlined,
        color: kc.accentAlt,
        style: style,
        child: content.isNotEmpty
            ? rich()
            : _BulletList(items: _list(block['items']), style: style),
      ),
      'bullet_list' => _BulletList(items: _list(block['items']), style: style),
      'chemical_reaction' => MathBlock(
        latex: _str(formula['latex']),
        plainText: _str(formula['plain_text']),
        style: style,
      ),
      'equation' => MathBlock(
        latex: _str(block['latex']),
        plainText: _str(block['plain_text']),
        number: number is num ? number.toInt() : null,
        style: style,
      ),
      'table' => TableBlock(block: block, style: style),
      'figure' => FigureBlock(block: block, style: style),
      _ => _unknown(type, rich, content.isEmpty),
    };
  }

  Widget _unknown(String type, Widget Function() rich, bool empty) {
    if (_loggedUnknown.add(type)) {
      appLog.warn('renderer: unknown block type "$type" (shown as text)');
    }
    return empty ? const SizedBox.shrink() : rich();
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.text,
    required this.level,
    required this.style,
  });

  final String text;
  final int level;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final size = switch (level) {
      <= 1 => 22.0,
      2 => 19.0,
      _ => 17.0,
    };
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Text(
        text,
        style: style.body.copyWith(
          fontSize: size * style.scale,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.label,
    required this.icon,
    required this.color,
    required this.style,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Color color;
  final BlockStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: KSpace.xs),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * style.scale,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.xs),
          child,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.style});

  final List<Object?> items;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 9 * style.scale),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: style.kc.accentText,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: RichBlockText(
                    text: item is Map ? _str(item['content']) : _str(item),
                    highlights: item is Map
                        ? _list(item['highlights'])
                        : const <Object?>[],
                    style: style,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
