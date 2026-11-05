import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/assess/assess_models.dart' show pickText;
import '../../data/catalog/catalog.dart' show localized;
import '../../data/coins/coins_models.dart';
import '../../data/coins/coins_providers.dart';
import '../../data/coins/stories_models.dart';
import '../../data/lessons/lesson_content.dart' show pickLanguage;
import '../../l10n/app_localizations.dart';
import '../../render/math_text.dart';

/// Texts of a question story in the best available language.
({String prompt, List<String> options, String explanation}) questionTexts(
  Story story,
  String lang,
) {
  final i18n = asMap(story.payload['i18n']);
  final m = asMap(i18n[pickLanguage(i18n.keys, lang)]);
  return (
    prompt: '${m['prompt'] ?? ''}',
    options: [for (final o in asList(m['options'])) '$o'],
    explanation: '${m['explanation'] ?? ''}',
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.fg,
    required this.fill,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color fg;
  final Color fill;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(KRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KRadius.button),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.lg,
                vertical: KSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MathText(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (icon != null) Icon(icon, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Question of the day / editorial question. Right = green, wrong = shake +
/// the right answer + why. The colours are instant (they come from the story
/// itself, even offline); the COINS shown are only what the server paid.
class QuestionStoryView extends ConsumerStatefulWidget {
  const QuestionStoryView({
    super.key,
    required this.story,
    required this.template,
    required this.onAnswered,
    required this.onCoins,
    required this.onGo,
  });

  final Story story;
  final StoryTemplate template;
  final VoidCallback onAnswered;
  final void Function(int coins) onCoins;
  final void Function(String path) onGo;

  @override
  ConsumerState<QuestionStoryView> createState() => _QuestionStoryViewState();
}

class _QuestionStoryViewState extends ConsumerState<QuestionStoryView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _busy = false;
  bool _asked = false;
  int? _coins;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _pick(int i) async {
    if (_busy || widget.story.answeredChoice != null) return;
    setState(() {
      _busy = true;
      _asked = true;
    });
    HapticFeedback.lightImpact();
    final notifier = ref.read(storiesControllerProvider.notifier);
    final pending = notifier.answer(widget.story, i);
    widget.onAnswered();
    final correct = i == widget.story.correctIndex;
    if (!correct && !MediaQuery.disableAnimationsOf(context)) {
      _shake.forward(from: 0);
    }
    final outcome = await pending;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _coins = outcome.coins;
    });
    final paid = outcome.coins ?? 0;
    if (paid > 0) widget.onCoins(paid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final kc = context.kc;
    final fg = widget.template.fg;
    final story = widget.story;
    final q = questionTexts(story, lang);
    final answered = story.answeredChoice;
    final right = story.correctIndex;
    final wrong = answered != null && answered != right;
    final yesterday = asMap(story.payload['yesterday']);
    final cta = localized(widget.template.cta, lang);
    final lessonId = story.lessonId;

    Widget option(int i) {
      Color fill = fg.withValues(alpha: 0.16);
      IconData? icon;
      var textColor = fg;
      if (answered != null) {
        if (i == right) {
          fill = kc.success;
          icon = Icons.check_circle_rounded;
        } else if (i == answered) {
          fill = kc.danger;
          icon = Icons.cancel_rounded;
        } else {
          fill = fg.withValues(alpha: 0.08);
          textColor = fg.withValues(alpha: 0.7);
        }
      }
      return _OptionTile(
        label: q.options[i],
        fg: textColor,
        fill: fill,
        icon: icon,
        onTap: answered == null && !_busy ? () => _pick(i) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MathText(
                  q.prompt,
                  style: TextStyle(
                    color: fg,
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KSpace.xl),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      math.sin(_shake.value * math.pi * 6) *
                          10 *
                          (1 - _shake.value),
                      0,
                    ),
                    child: child,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < q.options.length; i++) option(i),
                    ],
                  ),
                ),
                if (answered != null && q.explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: KSpace.md),
                  MathText(
                    q.explanation,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 15, height: 1.4),
                  ),
                ],
                if (answered != null && !wrong && _asked) ...[
                  const SizedBox(height: KSpace.md),
                  if ((_coins ?? 0) > 0)
                    Text(
                      '+$_coins',
                      style: TextStyle(
                        color: widget.template.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else if (_coins == null && !_busy)
                    Text(
                      l10n.storyCoinsPending,
                      style: TextStyle(color: fg.withValues(alpha: 0.85)),
                    ),
                ],
                if (yesterday.isNotEmpty) ...[
                  const SizedBox(height: KSpace.lg),
                  Text(
                    l10n.storyYesterday(asInt(yesterday['pct_correct'])),
                    style: TextStyle(color: fg.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (wrong && lessonId != null && cta.isNotEmpty) ...[
          const SizedBox(height: KSpace.md),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: widget.template.bg,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () =>
                widget.onGo('/modules/${story.moduleId}/lesson/$lessonId'),
            child: Text(cta),
          ),
        ],
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.icon, required this.text, required this.fg});

  final IconData icon;
  final String text;
  final Color fg;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.lg),
    child: Row(
      children: [
        Icon(icon, color: fg, size: 28),
        const SizedBox(width: KSpace.md),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Your plan": due cards + the next episode + an ESTIMATED time, one Start.
class PlanStoryView extends StatelessWidget {
  const PlanStoryView({
    super.key,
    required this.story,
    required this.template,
    required this.onGo,
  });

  final Story story;
  final StoryTemplate template;
  final void Function(String path) onGo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fg = template.fg;
    final p = story.payload;
    final due = asInt(p['due_cards']);
    final lessonId = story.lessonId;
    final moduleName = localized(asMap(p['module'])['name_i18n'], lang);
    final lessonTitle = pickText(p['lesson_title_i18n'], lang);
    final minutes = asInt(p['est_minutes']);
    final path = due > 0
        ? '/review'
        : (lessonId != null
              ? '/modules/${story.moduleId}/lesson/$lessonId'
              : null);
    final cta = localized(template.cta, lang);
    final empty = due <= 0 && lessonId == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (due > 0)
                  _PlanRow(
                    icon: Icons.style_rounded,
                    text: l10n.storyPlanDue(due),
                    fg: fg,
                  ),
                if (lessonId != null)
                  _PlanRow(
                    icon: Icons.menu_book_rounded,
                    text: l10n.storyPlanLesson(
                      lessonTitle.isEmpty ? moduleName : lessonTitle,
                    ),
                    fg: fg,
                  ),
                if (minutes > 0)
                  _PlanRow(
                    icon: Icons.schedule_rounded,
                    text: l10n.storyPlanMinutes(minutes),
                    fg: fg,
                  ),
                if (empty)
                  _PlanRow(
                    icon: Icons.emoji_events_rounded,
                    text: l10n.storyPlanDone,
                    fg: fg,
                  ),
              ],
            ),
          ),
        ),
        if (path != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: template.bg,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => onGo(path),
            child: Text(
              cta.isEmpty
                  ? MaterialLocalizations.of(context).continueButtonLabel
                  : cta,
            ),
          ),
      ],
    );
  }
}

/// "Your streak": the number counts up, the next badge, freezes, Share.
class StreakStoryView extends StatelessWidget {
  const StreakStoryView({
    super.key,
    required this.story,
    required this.template,
    required this.onShare,
  });

  final Story story;
  final StoryTemplate template;
  final void Function(int streak) onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final fg = template.fg;
    final p = story.payload;
    final current = asInt(p['current']);
    final best = asInt(p['best']);
    final freezes = asInt(p['freezes']);
    final next = p['next_milestone'] is num ? asInt(p['next_milestone']) : null;
    final daysToNext = asInt(p['days_to_next']);
    final reward = asInt(p['next_reward']);
    final protect = p['protected'] == true && p['studied_today'] != true;
    final cta = localized(template.cta, lang);
    final small = TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: KSpace.lg),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Column(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 96 + 24 * t,
                        color: template.accent,
                      ),
                      Text(
                        '${(current * t).round()}',
                        style: TextStyle(
                          color: fg,
                          fontSize: 72,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KSpace.sm),
                Text(
                  l10n.storyStreakDays(current),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (best > current) ...[
                  const SizedBox(height: KSpace.sm),
                  Text(l10n.storyStreakBest(best), style: small),
                ],
                if (next != null && daysToNext > 0) ...[
                  const SizedBox(height: KSpace.lg),
                  Text(
                    l10n.storyStreakNext(daysToNext, next, reward),
                    textAlign: TextAlign.center,
                    style: small,
                  ),
                ],
                if (freezes > 0) ...[
                  const SizedBox(height: KSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ac_unit_rounded, color: fg, size: 20),
                      const SizedBox(width: KSpace.sm),
                      Text(l10n.storyStreakFreezes(freezes), style: small),
                    ],
                  ),
                ],
                if (protect) ...[
                  const SizedBox(height: KSpace.md),
                  Text(
                    l10n.storyStreakProtected,
                    textAlign: TextAlign.center,
                    style: small,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (cta.isNotEmpty)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: template.bg,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => onShare(current),
            icon: const Icon(Icons.share_rounded),
            label: Text(cta),
          ),
      ],
    );
  }
}

/// Editorial story without a question: a title, a text, an optional link.
class GenericStoryView extends StatelessWidget {
  const GenericStoryView({
    super.key,
    required this.story,
    required this.template,
  });

  final Story story;
  final StoryTemplate template;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final fg = template.fg;
    final title = pickText(story.payload['title'], lang);
    final body = pickText(story.payload['body'], lang);
    final uri = Uri.tryParse('${story.payload['link'] ?? ''}');
    final link = uri != null && uri.scheme == 'https' ? uri : null;
    final cta = localized(template.cta, lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty)
                  MathText(
                    title,
                    style: TextStyle(
                      color: fg,
                      fontSize: 26,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: KSpace.lg),
                  MathText(
                    body,
                    style: TextStyle(color: fg, fontSize: 18, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (link != null && cta.isNotEmpty)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: template.bg,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () =>
                launchUrl(link, mode: LaunchMode.externalApplication),
            child: Text(cta),
          ),
      ],
    );
  }
}
