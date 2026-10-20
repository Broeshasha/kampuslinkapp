import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/learning/progress_repository.dart';
import '../../data/lessons/lesson_content.dart';
import '../../data/lessons/lesson_providers.dart';
import '../../data/lessons/lesson_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../render/lesson_view.dart';
import '../../render/reader_settings.dart';
import '../../ui/states.dart';

/// The lesson reader: header, blocks, resume (MASTER_PLAN 7.7), text size,
/// lesson language, "Mark as done" -> next lesson. Works fully offline.
class LessonReaderPage extends ConsumerStatefulWidget {
  const LessonReaderPage({
    super.key,
    required this.moduleId,
    required this.lessonId,
  });

  final int moduleId;
  final int lessonId;

  @override
  ConsumerState<LessonReaderPage> createState() => _LessonReaderPageState();
}

class _LessonReaderPageState extends ConsumerState<LessonReaderPage> {
  final _view = GlobalKey<LessonViewState>();
  late final LessonRepository _lessons;
  late final ProgressRepository _progress;
  late final AppLifecycleListener _life;
  Timer? _debounce;

  bool _loading = true;
  LessonRow? _row;
  LessonRow? _next;
  String? _resumeId;
  String? _contentLang;
  String? _currentId;
  String? _pendingId;
  double _pendingProgress = 0;

  @override
  void initState() {
    super.initState();
    _lessons = ref.read(lessonRepositoryProvider);
    _progress = ref.read(progressRepositoryProvider);
    _life = AppLifecycleListener(onHide: _flush, onPause: _flush);
    _load();
  }

  Future<void> _load() async {
    final row = await _lessons.lesson(widget.lessonId);
    final position = await _lessons.readingPosition(widget.lessonId);
    final next = row == null ? null : await _lessons.nextLesson(row);
    if (!mounted) return;
    setState(() {
      _row = row;
      _next = next;
      _resumeId = position?.blockId;
      _loading = false;
    });
  }

  void _onPosition(String blockId, double progress) {
    _pendingId = blockId;
    _pendingProgress = progress;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _flush);
    if (blockId != _currentId) setState(() => _currentId = blockId);
  }

  /// Saves the position now (debounce end, leaving, app in background).
  void _flush() {
    _debounce?.cancel();
    final id = _pendingId;
    if (id == null) return;
    _pendingId = null;
    unawaited(
      guard(
        () => _progress.saveReadingPosition(
          widget.lessonId,
          id,
          _pendingProgress,
        ),
      ),
    );
  }

  Future<void> _markDone(LessonRow row) async {
    await guard(() => _progress.completeLesson(row.id));
  }

  void _leave() {
    final next = _next;
    if (next != null) {
      context.go('/modules/${widget.moduleId}/lesson/${next.id}');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/modules/${widget.moduleId}');
    }
  }

  @override
  void dispose() {
    _flush();
    _life.dispose();
    super.dispose();
  }

  String _languageName(AppLocalizations l10n, String code) => switch (code) {
    'ar' => l10n.languageNameAr,
    'fr' => l10n.languageNameFr,
    'en' => l10n.languageNameEn,
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final row = _row;
    if (_loading) return const Scaffold(body: LoadingView());
    if (row == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(icon: Icons.search_off, title: l10n.lessonNotFound),
      );
    }
    final uiLang = Localizations.localeOf(context).languageCode;
    final content = LessonContent.of(row, _contentLang ?? uiLang);
    final blocks = content.blocks;
    final step = ref.watch(readerScaleStepProvider);
    final done = switch (ref.watch(lessonDoneProvider(row.id))) {
      AsyncData(:final value) => value,
      _ => false,
    };
    final accent = moduleAccent(widget.moduleId);
    final resumeIndex = _resumeId == null
        ? -1
        : blocks.indexWhere((b) => '${b['id']}' == _resumeId);
    final currentIndex = _currentId == null
        ? resumeIndex
        : blocks.indexWhere((b) => '${b['id']}' == _currentId);
    final showResume = resumeIndex > 1 && currentIndex < resumeIndex - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (content.languages.length > 1)
            PopupMenuButton<String>(
              tooltip: l10n.lessonLanguage,
              icon: const Icon(Icons.translate_rounded),
              initialValue: content.language,
              onSelected: (code) => setState(() => _contentLang = code),
              itemBuilder: (_) => [
                for (final code in content.languages)
                  PopupMenuItem(
                    value: code,
                    child: Text(_languageName(l10n, code)),
                  ),
              ],
            ),
          PopupMenuButton<int>(
            tooltip: l10n.readerTextSize,
            icon: const Icon(Icons.format_size_rounded),
            initialValue: step,
            onSelected: (s) =>
                ref.read(readerScaleStepProvider.notifier).setStep(s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('A-')),
              PopupMenuItem(value: 1, child: Text('A')),
              PopupMenuItem(value: 2, child: Text('A+')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          LessonView(
            key: _view,
            blocks: blocks,
            language: content.language,
            scale: readerScale(step),
            initialBlockId: _resumeId,
            onPosition: _onPosition,
            header: _LessonHeader(content: content, accent: accent),
            footer: _LessonFooter(
              done: done,
              hasNext: _next != null,
              accent: accent,
              onDone: () => _markDone(row),
              onNext: _leave,
            ),
          ),
          if (showResume)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: KSpace.xl,
              child: Center(
                child: ActionChip(
                  avatar: Icon(Icons.bookmark_rounded, color: accent),
                  label: Text(l10n.backToWhereYouStopped),
                  onPressed: () {
                    final id = _resumeId;
                    if (id != null) _view.currentState?.jumpToBlock(id);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.content, required this.accent});

  final LessonContent content;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final n = content.unitNumber;
    final unit = [
      if (n != null) l10n.chapterLabel(n),
      if (content.unitTitle.isNotEmpty) content.unitTitle,
    ].join(' \u00b7 ');
    final minutes = content.row.estimatedMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unit.isNotEmpty)
            Text(
              unit.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          const SizedBox(height: KSpace.xs),
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (minutes != null) ...[
            const SizedBox(height: KSpace.sm),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: kc.textSecondary),
                const SizedBox(width: KSpace.xs),
                Text(
                  l10n.minutesShort(minutes),
                  style: TextStyle(color: kc.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: KSpace.md),
          Divider(color: kc.border, height: 1),
        ],
      ),
    );
  }
}

class _LessonFooter extends StatelessWidget {
  const _LessonFooter({
    required this.done,
    required this.hasNext,
    required this.accent,
    required this.onDone,
    required this.onNext,
  });

  final bool done;
  final bool hasNext;
  final Color accent;
  final VoidCallback onDone;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.xl),
      child: Column(
        children: [
          if (!done)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: KSpace.md),
                ),
                onPressed: onDone,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(l10n.markAsDone),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: kc.success),
                const SizedBox(width: KSpace.sm),
                Text(
                  l10n.lessonDone,
                  style: TextStyle(
                    color: kc.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpace.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onNext,
                child: Text(hasNext ? l10n.nextLesson : l10n.backToModule),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
