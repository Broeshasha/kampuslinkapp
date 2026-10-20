import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';
import '../ui/max_width.dart';
import 'block_style.dart';
import 'block_view.dart';

/// Reports the first visible block id and how far the student is (0..1).
typedef BlockPositionCallback = void Function(String blockId, double progress);

/// A lesson = the student blocks in one scroll view (CONTENT_FORMAT 5.1).
/// The lesson language decides direction and block labels, independent of
/// the UI. Knows which block is on top (resume, MASTER_PLAN 7.7) and can
/// jump to a block id; ids are the same in every language, so the place is
/// kept when the language or the text size changes.
class LessonView extends StatefulWidget {
  const LessonView({
    super.key,
    required this.blocks,
    required this.language,
    this.scale = 1.0,
    this.initialBlockId,
    this.onPosition,
    this.header,
    this.footer,
  });

  final List<Map<String, dynamic>> blocks;
  final String language;
  final double scale;
  final String? initialBlockId;
  final BlockPositionCallback? onPosition;
  final Widget? header;
  final Widget? footer;

  @override
  State<LessonView> createState() => LessonViewState();
}

class LessonViewState extends State<LessonView> {
  final _scroll = ScrollController();
  final _content = GlobalKey();
  final _keys = <int, GlobalKey>{};
  String? _currentId;

  /// The block at the top of the screen (null until the first scroll/jump).
  String? get currentBlockId => _currentId;

  @override
  void initState() {
    super.initState();
    final id = widget.initialBlockId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToBlock(id));
    }
  }

  @override
  void didUpdateWidget(LessonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = _currentId;
    if (id != null &&
        (oldWidget.language != widget.language ||
            oldWidget.scale != widget.scale)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToBlock(id));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  /// Puts block [id] at the top of the screen (no-op if it does not exist).
  void jumpToBlock(String id) {
    if (!mounted) return;
    final index = widget.blocks.indexWhere((b) => '${b['id']}' == id);
    final target = index < 0 ? null : _keys[index]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || !_scroll.hasClients) return;
    final content = _content.currentContext?.findRenderObject();
    if (content is! RenderBox) return;
    final top = _scroll.offset;
    String? found;
    for (var i = 0; i < widget.blocks.length; i++) {
      final box = _keys[i]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero, ancestor: content).dy;
      if (y + box.size.height > top + 1) {
        found = '${widget.blocks[i]['id']}';
        break;
      }
    }
    if (found == null) return;
    final max = _scroll.position.maxScrollExtent;
    final progress = max <= 0 ? 1.0 : (top / max).clamp(0.0, 1.0).toDouble();
    _currentId = found;
    widget.onPosition?.call(found, progress);
  }

  @override
  Widget build(BuildContext context) {
    final lang = supportedLanguageCodes.contains(widget.language)
        ? widget.language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: widget.scale,
      kc: context.kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    final header = widget.header;
    final footer = widget.footer;
    return Directionality(
      textDirection: style.direction,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _measure();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          child: KeyedSubtree(
            key: _content,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpace.lg,
                KSpace.md,
                KSpace.lg,
                KSpace.xxl * 3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) MaxWidth(child: header),
                  for (var i = 0; i < widget.blocks.length; i++)
                    KeyedSubtree(
                      key: _keyFor(i),
                      child: MaxWidth(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: KSpace.md),
                          child: BlockView(
                            key: ValueKey<String>('${widget.blocks[i]['id']}'),
                            block: widget.blocks[i],
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  if (footer != null) MaxWidth(child: footer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
