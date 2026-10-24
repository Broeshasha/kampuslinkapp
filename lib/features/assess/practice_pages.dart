import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/assess/assess_models.dart';
import '../../data/assess/assess_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../cases/report_sheet.dart';
import 'assess_widgets.dart';

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// Module > Practice: one row per chapter (from the manifest).
class PracticeChaptersPage extends ConsumerWidget {
  const PracticeChaptersPage({super.key, required this.moduleId});

  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final index = ref.watch(practiceIndexProvider(moduleId)).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.practiceTitle)),
      body: index == null
          ? const LoadingView()
          : index.isEmpty
          ? EmptyView(
              icon: Icons.edit_note_rounded,
              title: l10n.assessNotDownloaded,
            )
          : ListView(
              padding: const EdgeInsets.all(KSpace.lg),
              children: [
                for (final c
                    in [...index]..sort(
                      (a, b) =>
                          _n(a['unit_number']).compareTo(_n(b['unit_number'])),
                    ))
                  MaxWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: KSpace.sm),
                      child: Material(
                        color: kc.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadius.chip),
                          side: BorderSide(color: kc.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(
                            Icons.edit_note_rounded,
                            color: kc.accentText,
                          ),
                          title: Text(l10n.chapterLabel(_n(c['unit_number']))),
                          subtitle: Text(l10n.practiceCount(_n(c['count']))),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PracticeChapterPage(
                                moduleId: moduleId,
                                chapterRef: '${c['chapter_ref']}',
                                unitNumber: _n(c['unit_number']),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class PracticeChapterPage extends ConsumerWidget {
  const PracticeChapterPage({
    super.key,
    required this.moduleId,
    required this.chapterRef,
    required this.unitNumber,
  });

  final int moduleId;
  final String chapterRef;
  final int unitNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = assessLang(context);
    final raw = ref
        .watch(practiceChapterProvider((moduleId, chapterRef)))
        .value;
    final items = [
      for (final m in raw ?? const <Map<String, dynamic>>[])
        PracticeItem.fromMap(m, lang),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chapterLabel(unitNumber))),
      body: raw == null
          ? const LoadingView()
          : items.isEmpty
          ? EmptyView(
              icon: Icons.edit_note_rounded,
              title: l10n.assessNotDownloaded,
            )
          : ListView(
              padding: const EdgeInsets.all(KSpace.lg),
              children: [
                for (var i = 0; i < items.length; i++)
                  MaxWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: KSpace.sm),
                      child: Material(
                        color: kc.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadius.chip),
                          side: BorderSide(color: kc.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: _RatingIcon(id: items[i].id),
                          title: Text(
                            items[i].title.isEmpty
                                ? l10n.exerciseNumber(i + 1)
                                : items[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: items[i].difficulty == null
                              ? null
                              : Text('\u2605' * items[i].difficulty!),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PracticeItemPage(
                                moduleId: moduleId,
                                chapterRef: chapterRef,
                                practiceId: items[i].id,
                                number: i + 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RatingIcon extends ConsumerWidget {
  const _RatingIcon({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final p = ref.watch(practiceProgressProvider(id)).value;
    return switch (p?['self_rating']) {
      'got_it' => Icon(Icons.check_circle_rounded, color: kc.success),
      'partly' => Icon(Icons.adjust_rounded, color: kc.warning),
      'missed' => Icon(Icons.cancel_rounded, color: kc.danger),
      _ =>
        p?['solution_seen'] == true
            ? Icon(Icons.visibility_rounded, color: kc.textSecondary)
            : Icon(Icons.circle_outlined, color: kc.textSecondary),
    };
  }
}

/// One practice exercise: statement, then the parts one by one with
/// "Hint" (one at a time) and "Show solution"; then Got it / Partly / Missed.
class PracticeItemPage extends ConsumerStatefulWidget {
  const PracticeItemPage({
    super.key,
    required this.moduleId,
    required this.chapterRef,
    required this.practiceId,
    this.number = 1,
  });

  final int moduleId;
  final String chapterRef;
  final int practiceId;
  final int number;

  @override
  ConsumerState<PracticeItemPage> createState() => _PracticeItemPageState();
}

class _PracticeItemPageState extends ConsumerState<PracticeItemPage> {
  final _hints = <String, int>{};
  final _solved = <String>{};
  int _shownParts = 1;
  String? _rating;

  int get _hintsSeen => _hints.values.fold(0, (a, b) => a + b);

  void _save() {
    guard(
      () => ref
          .read(assessStoreProvider)
          .savePracticeProgress(
            widget.practiceId,
            hintsSeen: _hintsSeen,
            solutionSeen: _solved.isNotEmpty,
            rating: _rating,
          ),
    ).then((_) {
      if (mounted) ref.invalidate(practiceProgressProvider(widget.practiceId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = assessLang(context);
    final raw = ref
        .watch(practiceChapterProvider((widget.moduleId, widget.chapterRef)))
        .value;
    PracticeItem? item;
    for (final m in raw ?? const <Map<String, dynamic>>[]) {
      if ('${m['id']}' == '${widget.practiceId}') {
        item = PracticeItem.fromMap(m, lang);
      }
    }
    final it = item;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          it == null || it.title.isEmpty
              ? l10n.exerciseNumber(widget.number)
              : it.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l10n.reportMistake,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => showReportMistake(
              context,
              ref,
              targetType: 'practice',
              targetId: '${widget.practiceId}',
            ),
          ),
        ],
      ),
      body: it == null
          ? (raw == null
                ? const LoadingView()
                : EmptyView(
                    icon: Icons.search_off,
                    title: l10n.assessNotDownloaded,
                  ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                KSpace.lg,
                KSpace.md,
                KSpace.lg,
                KSpace.xxl * 2,
              ),
              children: [
                MaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AssessText(it.statement),
                      AssessMedia(figure: it.figure, table: it.table),
                      for (
                        var i = 0;
                        i < it.parts.length && i < _shownParts;
                        i++
                      )
                        _part(context, it.parts[i], i),
                      if (_shownParts < it.parts.length)
                        Padding(
                          padding: const EdgeInsets.only(top: KSpace.md),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _shownParts++),
                            icon: const Icon(Icons.arrow_downward_rounded),
                            label: Text(l10n.practiceNextPart),
                          ),
                        ),
                      if (_solved.isNotEmpty) ...[
                        const SizedBox(height: KSpace.xl),
                        Text(
                          l10n.practiceRate,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: KSpace.sm),
                        Wrap(
                          spacing: KSpace.sm,
                          runSpacing: KSpace.sm,
                          children: [
                            for (final (key, label, color) in [
                              ('got_it', l10n.rateGotIt, kc.success),
                              ('partly', l10n.ratePartly, kc.warning),
                              ('missed', l10n.rateMissed, kc.danger),
                            ])
                              ChoiceChip(
                                key: ValueKey<String>('rate-$key'),
                                label: Text(label),
                                selected: _rating == key,
                                selectedColor: color.withValues(alpha: 0.25),
                                onSelected: (_) {
                                  setState(() => _rating = key);
                                  _save();
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _part(BuildContext context, PracticePart p, int index) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final shown = _hints[p.id] ?? 0;
    final solved = _solved.contains(p.id);
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.id.isEmpty ? '${index + 1})' : '${p.id})',
                style: TextStyle(
                  color: kc.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Expanded(child: AssessText(p.prompt)),
            ],
          ),
          for (var h = 0; h < shown && h < p.hints.length; h++)
            Padding(
              padding: const EdgeInsets.only(top: KSpace.sm),
              child: AssessBox(
                color: kc.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.practiceHintCount(h + 1, p.hints.length),
                      style: TextStyle(
                        color: kc.warning,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: KSpace.xs),
                    AssessText(p.hints[h]),
                  ],
                ),
              ),
            ),
          const SizedBox(height: KSpace.sm),
          Wrap(
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              if (!solved && shown < p.hints.length)
                OutlinedButton.icon(
                  key: ValueKey<String>('hint-${p.id}'),
                  onPressed: () {
                    setState(() => _hints[p.id] = shown + 1);
                    _save();
                  },
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: Text(l10n.practiceHint),
                ),
              if (!solved)
                FilledButton.icon(
                  key: ValueKey<String>('solve-${p.id}'),
                  onPressed: () {
                    setState(() => _solved.add(p.id));
                    _save();
                  },
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(l10n.practiceShowSolution),
                ),
            ],
          ),
          if (solved)
            SolutionView(
              steps: p.steps,
              answer: p.answer,
              figure: p.figure,
              code: p.code,
            ),
        ],
      ),
    );
  }
}
