import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/assess/assess_models.dart';
import '../../data/assess/assess_providers.dart';
import '../../data/assess/assess_store.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../cases/report_sheet.dart';
import 'assess_widgets.dart';

/// Module > Mock exams: every paper with its best score /20.
class ExamListPage extends ConsumerWidget {
  const ExamListPage({super.key, required this.moduleId});

  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = assessLang(context);
    final index = ref.watch(examIndexProvider(moduleId)).value;
    final headers = [
      for (final m in index ?? const <Map<String, dynamic>>[])
        ExamHeader.fromMap(m, lang),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.examsTitle)),
      body: index == null
          ? const LoadingView()
          : headers.isEmpty
          ? EmptyView(
              icon: Icons.assignment_outlined,
              title: l10n.assessNotDownloaded,
            )
          : ListView(
              padding: const EdgeInsets.all(KSpace.lg),
              children: [
                for (final h in headers)
                  MaxWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: KSpace.md),
                      child: _PaperCard(moduleId: moduleId, header: h),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PaperCard extends ConsumerWidget {
  const _PaperCard({required this.moduleId, required this.header});

  final int moduleId;
  final ExamHeader header;

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    ExamPaper paper,
  ) async {
    final l10n = AppLocalizations.of(context);
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              paper.title.isEmpty ? l10n.examsTitle : paper.title,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              l10n.examMeta(paper.durationMin, formatPoints(paper.totalPoints)),
            ),
            const SizedBox(height: KSpace.md),
            AssessText(paper.instructions),
            const SizedBox(height: KSpace.md),
            AssessBox(color: sheet.kc.accent, child: Text(l10n.examOnPaper)),
            const SizedBox(height: KSpace.lg),
            FilledButton.icon(
              onPressed: () => Navigator.of(sheet).pop(true),
              icon: const Icon(Icons.timer_outlined),
              label: Text(l10n.examStart),
            ),
          ],
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final now = DateTime.now();
    final attempt = ExamAttempt(
      attemptId: const Uuid().v4(),
      paperId: paper.id,
      status: AttemptStatus.inProgress,
      startedAt: now,
      at: now,
    );
    await guard(() => ref.read(assessStoreProvider).saveAttempt(attempt));
    ref.invalidate(examAttemptsProvider(paper.id));
    if (!context.mounted) return;
    await _open(context, attempt.attemptId);
  }

  Future<void> _open(BuildContext context, String attemptId) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamPage(paperId: header.id, attemptId: attemptId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = assessLang(context);
    final raw = ref.watch(examPaperProvider(header.id)).value;
    final paper = raw == null ? null : ExamPaper.fromMap(raw, lang);
    final attempts =
        ref.watch(examAttemptsProvider(header.id)).value ??
        const <ExamAttempt>[];
    final best = paper == null ? null : bestScore20(attempts, paper);
    final open = openAttempt(attempts);
    final done = lastFinished(attempts);
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.card),
        side: BorderSide(color: kc.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: kc.accentText),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Text(
                    header.title.isEmpty ? l10n.examsTitle : header.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (best != null)
                  Text(
                    l10n.examBest(formatPoints(best)),
                    style: TextStyle(
                      color: kc.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KSpace.xs),
            Text(
              l10n.examMeta(
                header.durationMin,
                formatPoints(header.totalPoints),
              ),
              style: TextStyle(color: kc.textSecondary),
            ),
            const SizedBox(height: KSpace.md),
            if (paper == null)
              Text(
                l10n.assessNotDownloaded,
                style: TextStyle(color: kc.textSecondary),
              )
            else
              Wrap(
                spacing: KSpace.sm,
                runSpacing: KSpace.sm,
                children: [
                  if (open != null)
                    FilledButton.icon(
                      onPressed: () => _open(context, open.attemptId),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(l10n.examResume),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => _start(context, ref, paper),
                      icon: const Icon(Icons.timer_outlined),
                      label: Text(l10n.examStart),
                    ),
                  if (done != null)
                    OutlinedButton.icon(
                      onPressed: () => _open(context, done.attemptId),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.examCorrection),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Remaining time of an attempt (never negative).
Duration examRemaining(ExamAttempt a, int durationMin, DateTime now) {
  final end = a.startedAt.add(Duration(minutes: durationMin));
  final left = end.difference(now);
  return left.isNegative ? Duration.zero : left;
}

String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Exam mode (statements only, countdown) then correction mode (solutions,
/// marking, points per part). The timer follows started_at, so it keeps
/// running while the app is in the background.
class ExamPage extends ConsumerStatefulWidget {
  const ExamPage({
    super.key,
    required this.paperId,
    required this.attemptId,
    this.now,
  });

  final int paperId;
  final String attemptId;

  /// Tests pass a clock.
  final DateTime Function()? now;

  @override
  ConsumerState<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends ConsumerState<ExamPage> {
  ExamAttempt? _attempt;
  Timer? _timer;
  bool _warned = false;
  bool _finishing = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ref.read(assessStoreProvider).attempts(widget.paperId);
    if (!mounted) return;
    for (final a in list) {
      if (a.attemptId == widget.attemptId) setState(() => _attempt = a);
    }
  }

  ExamPaper? _paper() {
    final raw = ref.read(examPaperProvider(widget.paperId)).value;
    return raw == null ? null : ExamPaper.fromMap(raw, assessLang(context));
  }

  void _tick() {
    if (!mounted) return;
    final a = _attempt;
    final paper = _paper();
    if (a == null || paper == null) return;
    if (a.status != AttemptStatus.inProgress) return;
    final left = examRemaining(a, paper.durationMin, _now());
    if (left == Duration.zero) {
      _finish(timeUp: true);
      return;
    }
    if (!_warned && left <= const Duration(minutes: 10)) {
      _warned = true;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).examTenMinutes)),
      );
    }
    setState(() {});
  }

  Future<void> _save(ExamAttempt a) async {
    setState(() => _attempt = a);
    await guard(() => ref.read(assessStoreProvider).saveAttempt(a));
    if (mounted) ref.invalidate(examAttemptsProvider(widget.paperId));
  }

  Future<void> _finish({bool timeUp = false}) async {
    final a = _attempt;
    if (a == null || _finishing || a.status != AttemptStatus.inProgress) {
      return;
    }
    _finishing = true;
    final now = _now();
    await _save(
      a.copyWith(status: AttemptStatus.finished, finishedAt: now, at: now),
    );
    _finishing = false;
    if (timeUp && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).examTimeUp)),
      );
    }
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(l10n.examKeepGoing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _askFinish() async {
    final l10n = AppLocalizations.of(context);
    if (await _confirm(
      l10n.examFinish,
      l10n.examFinishConfirm,
      l10n.examFinish,
    )) {
      await _finish();
    }
  }

  Future<void> _askQuit() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (!await _confirm(l10n.examQuitTitle, l10n.examQuitBody, l10n.examQuit)) {
      return;
    }
    final a = _attempt;
    if (a != null) {
      final now = _now();
      await _save(a.copyWith(status: AttemptStatus.abandoned, at: now));
    }
    navigator.pop();
  }

  void _setScore(String key, double value, double max) {
    final a = _attempt;
    if (a == null) return;
    HapticFeedback.selectionClick();
    final scores = {...a.scores, key: clampPoints(value, max)};
    _save(a.copyWith(scores: scores, at: _now()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final raw = ref.watch(examPaperProvider(widget.paperId)).value;
    final a = _attempt;
    if (raw == null || a == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    final paper = ExamPaper.fromMap(raw, assessLang(context));
    final inExam = a.status == AttemptStatus.inProgress;
    final left = examRemaining(a, paper.durationMin, _now());
    final kc = context.kc;
    final total = attemptTotal(a.scores, paper.maxByKey);
    return PopScope(
      canPop: !inExam,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inExam) _askQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !inExam,
          leading: inExam
              ? IconButton(
                  tooltip: l10n.examQuit,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _askQuit,
                )
              : null,
          title: inExam
              ? Row(
                  key: const ValueKey('exam-clock'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: left <= const Duration(minutes: 10)
                          ? kc.danger
                          : kc.textPrimary,
                    ),
                    const SizedBox(width: KSpace.xs),
                    Text(
                      _clock(left),
                      style: TextStyle(
                        color: left <= const Duration(minutes: 10)
                            ? kc.danger
                            : kc.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              : Text(l10n.examCorrection),
          actions: [
            if (inExam)
              TextButton(onPressed: _askFinish, child: Text(l10n.examFinish)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.md,
            KSpace.lg,
            KSpace.xxl * 2,
          ),
          children: [
            if (!inExam)
              MaxWidth(
                child: AssessBox(
                  color: kc.success,
                  child: Text(
                    key: const ValueKey('exam-total'),
                    '${l10n.examTotal(formatPoints(total), formatPoints(paper.totalPoints))}'
                    '  \u00b7  '
                    '${l10n.examOn20(formatPoints(score20(total, paper.totalPoints)))}',
                    style: TextStyle(
                      color: kc.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            for (var e = 0; e < paper.exercises.length; e++)
              MaxWidth(
                child: _exercise(context, paper, paper.exercises[e], e, inExam),
              ),
          ],
        ),
      ),
    );
  }

  Widget _exercise(
    BuildContext context,
    ExamPaper paper,
    ExamExercise ex,
    int index,
    bool inExam,
  ) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ex.title.isEmpty ? l10n.exerciseNumber(index + 1) : ex.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                l10n.examPoints(formatPoints(ex.points)),
                style: TextStyle(color: kc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: KSpace.sm),
          AssessText(ex.statement),
          AssessMedia(figure: ex.figure, table: ex.table),
          for (final p in ex.parts) _partView(context, paper, ex, p, inExam),
        ],
      ),
    );
  }

  Widget _partView(
    BuildContext context,
    ExamPaper paper,
    ExamExercise ex,
    ExamPart p,
    bool inExam,
  ) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final key = scoreKey(ex.id, p.id);
    final value = _attempt?.scores[key] ?? 0;
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${p.id})',
          style: TextStyle(color: kc.accentText, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: KSpace.sm),
        Expanded(child: AssessText(p.prompt)),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: KSpace.sm),
          child: Text(
            l10n.examPoints(formatPoints(p.points)),
            style: TextStyle(color: kc.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
    if (inExam) {
      return Padding(
        padding: const EdgeInsets.only(top: KSpace.md),
        child: head,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: AssessBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            const SizedBox(height: KSpace.sm),
            SolutionView(
              steps: p.steps,
              answer: p.answer,
              figure: p.figure,
              code: p.code,
            ),
            if (p.marking.isNotEmpty) ...[
              const SizedBox(height: KSpace.sm),
              Text(
                l10n.examMarking,
                style: TextStyle(
                  color: kc.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final m in p.marking)
                Padding(
                  padding: const EdgeInsets.only(top: KSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          m.points == null ? '\u2022' : formatPoints(m.points!),
                          style: TextStyle(
                            color: kc.accentText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(child: AssessText(m.criterion)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: KSpace.sm),
            // Wraps on narrow phones (320 px at 1.5x) instead of overflowing.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KSpace.xs,
              runSpacing: KSpace.xs,
              children: [
                Text(
                  l10n.examYourPoints,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey<String>('minus-$key'),
                      tooltip: '-0.25',
                      visualDensity: VisualDensity.compact,
                      onPressed: value <= 0
                          ? null
                          : () => _setScore(key, value - 0.25, p.points),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Text(
                      key: ValueKey<String>('points-$key'),
                      '${formatPoints(value)} / ${formatPoints(p.points)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      key: ValueKey<String>('plus-$key'),
                      tooltip: '+0.25',
                      visualDensity: VisualDensity.compact,
                      onPressed: value >= p.points
                          ? null
                          : () => _setScore(key, value + 0.25, p.points),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: l10n.reportMistake,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.flag_outlined, color: kc.textSecondary),
                  onPressed: () => showReportMistake(
                    context,
                    ref,
                    targetType: 'exam',
                    targetId: '${paper.id}',
                    notePrefix: key,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
