import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/lessons/lesson_content.dart';
import '../../data/motivation/bac_readiness.dart';
import '../../data/motivation/motivation_providers.dart';
import '../../data/shop/shop_providers.dart';
import '../../data/learning/feed_repository.dart' show dayKey;
import '../../data/motivation/motivation_store.dart';
import '../../l10n/app_localizations.dart';

/// MOT-1: Today's Mission = one round button in the Home header (next to
/// Continue / Shuffle). No extra row, the feed card keeps the screen.
/// The ring fills 1/3 per step; green check when done. Tap = the steps.
class MissionButton extends ConsumerWidget {
  const MissionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(missionProvider).value;
    if (mission == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return IconButton(
      tooltip: l10n.missionTitle,
      visualDensity: VisualDensity.compact,
      onPressed: () => showMissionSheet(context),
      icon: SizedBox(
        width: 26,
        height: 26,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: mission.ticks / 3,
              strokeWidth: 2.5,
              color: kc.success,
              backgroundColor: kc.border,
            ),
            Icon(
              mission.done ? Icons.check_rounded : Icons.flag_rounded,
              size: 15,
              color: mission.done ? kc.success : kc.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

void showMissionSheet(BuildContext context) {
  final router = GoRouter.of(context);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => _MissionSheet(
      onLesson: (l) {
        Navigator.of(sheet).pop();
        router.go('/modules/${l.moduleId}/lesson/${l.id}');
      },
      onQuiz: (l) {
        Navigator.of(sheet).pop();
        router.go('/modules/${l.moduleId}/lesson/${l.id}/quiz');
      },
      onCards: () => Navigator.of(sheet).pop(),
    ),
  );
}

class _MissionSheet extends ConsumerWidget {
  const _MissionSheet({
    required this.onLesson,
    required this.onQuiz,
    required this.onCards,
  });

  final void Function(LessonRow lesson) onLesson;
  final void Function(LessonRow lesson) onQuiz;
  final VoidCallback onCards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final m = ref.watch(missionProvider).value;
    final why = ref.watch(myWhyProvider).value ?? const MyWhy();
    final countdown = ref.watch(bacCountdownProvider);
    final readiness = ref.watch(bacReadinessProvider).value ?? const <SubjectReadiness>[];
    final frozen = ref.watch(walletControllerProvider)?.frozenWeeks ?? const <String>{};
    final lastWeekFrozen = frozen.contains(
      dayKey(m?.weekStart.subtract(const Duration(days: 7)) ?? DateTime(2000)),
    );
    if (m == null) return const SizedBox(height: 120);
    final nothing = m.cardsTarget == 0 && m.lesson == null && m.quizLesson == null;

    Widget step({
      required bool ok,
      required String title,
      String? subtitle,
      VoidCallback? onGo,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: ok ? kc.success : kc.textSecondary,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: ok || onGo == null
          ? null
          : FilledButton.tonal(onPressed: onGo, child: Text(l10n.missionGo)),
    );

    // Fact-based messages only (MOTIVATION_DESIGN 1 + 5).
    final String? message = m.weekReached
        ? l10n.weekReached(m.weekDays)
        : m.done
        ? l10n.missionDoneDay(m.weekDays)
        : m.weekDays == 0 && lastWeekFrozen
        ? l10n.weekFreezeUsed
        : m.weekDays == 0
        ? l10n.weekFreshStart
        : null;

    return SingleChildScrollView(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.md, KSpace.lg, KSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.missionTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (countdown != null) ...[
            const SizedBox(height: 2),
            Text(
              countdown.days
                  ? l10n.bacCountdownDays(countdown.value)
                  : l10n.bacCountdownWeeks(countdown.value),
              style: TextStyle(color: kc.accentText, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: KSpace.xs),
          _WeekDots(mission: m),
          const SizedBox(height: KSpace.xs),
          Text(
            l10n.weekGoalLabel(m.weekDays, m.weekGoal),
            style: TextStyle(color: kc.textSecondary),
          ),
          if (message != null) ...[
            const SizedBox(height: KSpace.sm),
            Text(message, style: TextStyle(color: kc.accentText, fontWeight: FontWeight.w600)),
          ],
          if (m.weekDays == 0 && !why.isEmpty) ...[
            const SizedBox(height: KSpace.sm),
            _WhyCard(why: why),
          ],
          const SizedBox(height: KSpace.md),
          if (nothing)
            Text(l10n.missionNothing, style: TextStyle(color: kc.textSecondary))
          else ...[
            if (m.cardsTarget > 0)
              step(
                ok: m.cardsOk,
                title: l10n.missionCards(m.cardsTarget),
                subtitle: l10n.missionCardsProgress(
                  m.cardsDone > m.cardsTarget ? m.cardsTarget : m.cardsDone,
                  m.cardsTarget,
                ),
                onGo: onCards,
              ),
            if (m.lesson != null || m.lessonDone)
              step(
                ok: m.lessonOk,
                title: l10n.missionLesson,
                subtitle: m.lesson == null ? null : lessonHeadline(m.lesson!, lang).title,
                onGo: m.lesson == null ? null : () => onLesson(m.lesson!),
              ),
            if (m.quizLesson != null)
              step(
                ok: m.quizOk,
                title: l10n.missionQuiz,
                subtitle: lessonHeadline(m.quizLesson!, lang).title,
                onGo: () => onQuiz(m.quizLesson!),
              ),
          ],
          if (readiness.isNotEmpty) ...[
            const SizedBox(height: KSpace.md),
            _Readiness(items: readiness),
          ],
        ],
      ),
      ),
    );
  }
}

class _Readiness extends StatelessWidget {
  const _Readiness({required this.items});

  final List<SubjectReadiness> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    String name(String key) => switch (key) {
      'svt' => l10n.bacSubjectSvt,
      'math' => l10n.bacSubjectMath,
      'phys' => l10n.bacSubjectPhys,
      _ => key,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.bacReadinessTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(l10n.bacReadinessHint, style: TextStyle(color: kc.textSecondary, fontSize: 12)),
        const SizedBox(height: KSpace.xs),
        for (final r in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name(r.subject.key))),
                    Text(
                      '${(r.value * 100).round()}% · ${l10n.bacCoef(r.subject.coef)}',
                      style: TextStyle(color: kc.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.value,
                    minHeight: 6,
                    color: kc.accent,
                    backgroundColor: kc.border,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.mission});

  final MissionStatus mission;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final ml = MaterialLocalizations.of(context);
    final today = DateTime.now();
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (_) {
              final d = mission.weekStart.add(Duration(days: i));
              final key =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              final on = mission.missionDays.contains(key);
              final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? kc.success : null,
                        border: Border.all(
                          color: on ? kc.success : (isToday ? kc.accent : kc.border),
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ml.narrowWeekdays[d.weekday % 7],
                      style: TextStyle(fontSize: 11, color: kc.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.why});

  final MyWhy why;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final labels = [for (final v in why.values) whyLabel(l10n, v)];
    final text = why.text.trim().isNotEmpty ? why.text.trim() : labels.join(' · ');
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: kc.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.whyShownTitle, style: TextStyle(color: kc.accentText, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(text),
        ],
      ),
    );
  }
}

String whyLabel(AppLocalizations l10n, String code) => switch (code) {
  'family' => l10n.whyValueFamily,
  'future_job' => l10n.whyValueFutureJob,
  'faith' => l10n.whyValueFaith,
  'prove_myself' => l10n.whyValueProveMyself,
  'scholarship' => l10n.whyValueScholarship,
  _ => l10n.whyValueOther,
};
