import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/learning/quiz_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/compact_figure.dart';
import '../../render/rich_block_text.dart';
import '../../ui/confetti.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../cases/report_sheet.dart';
import '../home/study_activity.dart';

/// Lesson quiz: one question per screen, instant feedback + explanation,
/// progress bar, results with score and confetti. Resumes where it was
/// interrupted (answers are saved on the phone as they are given).
class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, required this.moduleId, required this.lessonId});

  final int moduleId;
  final int lessonId;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  late final QuizRepository _quiz;
  List<QuizQuestion>? _questions;
  Map<int, int> _answers = {};
  int _index = 0;
  int? _chosen;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _quiz = ref.read(quizRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    final questions = await _quiz.questions(widget.lessonId, lang);
    final answers = await _quiz.savedAnswers(widget.lessonId);
    if (!mounted) return;
    var index = questions.indexWhere((q) => !answers.containsKey(q.id));
    if (index < 0) index = questions.length;
    setState(() {
      _questions = questions;
      _answers = answers;
      _index = index;
    });
    if (questions.isNotEmpty && index >= questions.length) _saveResult();
  }

  int get _correct {
    final qs = _questions ?? const <QuizQuestion>[];
    return qs.where((q) => _answers[q.id] == q.correctIndex).length;
  }

  void _saveResult() {
    if (_saved) return;
    _saved = true;
    final total = _questions?.length ?? 0;
    final score = total == 0 ? 0 : (_correct * 100 / total).round();
    guard(() => _quiz.finish(widget.lessonId, score));
  }

  Future<void> _choose(QuizQuestion q, int choice) async {
    if (_chosen != null) return;
    setState(() {
      _chosen = choice;
      _answers = {..._answers, q.id: choice};
    });
    final correct = choice == q.correctIndex;
    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    await guard(() => _quiz.answer(widget.lessonId, q, choice));
  }

  void _next() {
    final total = _questions?.length ?? 0;
    setState(() {
      _index++;
      _chosen = null;
    });
    if (_index >= total) _saveResult();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/modules/${widget.moduleId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final questions = _questions;
    final Widget body;
    if (questions == null) {
      body = const LoadingView();
    } else if (questions.isEmpty) {
      body = EmptyView(icon: Icons.quiz_outlined, title: l10n.quizNoQuestions);
    } else if (_index >= questions.length) {
      body = _Results(
        correct: _correct,
        total: questions.length,
        onFinish: _close,
      );
    } else {
      final q = questions[_index];
      body = _QuestionView(
        question: q,
        index: _index,
        total: questions.length,
        chosen: _chosen,
        onChoose: (i) => _choose(q, i),
        onNext: _next,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quizTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
        actions: [
          if (questions != null && _index < questions.length)
            IconButton(
              tooltip: l10n.reportMistake,
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showReportMistake(
                context,
                ref,
                targetType: 'question',
                targetId: '${questions[_index].id}',
                lessonId: widget.lessonId,
              ),
            ),
        ],
      ),
      body: StudyActivity(child: body),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.index,
    required this.total,
    required this.chosen,
    required this.onChoose,
    required this.onNext,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final int? chosen;
  final ValueChanged<int> onChoose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = supportedLanguageCodes.contains(question.language)
        ? question.language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: 1.1,
      kc: kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    final answered = chosen;
    final correct = answered != null && answered == question.correctIndex;
    final options = question.options.isNotEmpty
        ? question.options
        : [l10n.trueLabel, l10n.falseLabel];
    return ListView(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (index + (answered == null ? 0 : 1)) / total,
                  minHeight: 8,
                  color: kc.accent,
                  backgroundColor: kc.accent.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: KSpace.sm),
              Text(
                l10n.questionOf(index + 1, total),
                style: TextStyle(color: kc.textSecondary),
              ),
              const SizedBox(height: KSpace.lg),
              Directionality(
                textDirection: style.direction,
                child: RichBlockText(
                  text: question.prompt,
                  style: BlockStyle(
                    language: lang,
                    scale: 1.25,
                    kc: kc,
                    labels: style.labels,
                    base: style.base.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (question.figure case final fig?) ...[
                const SizedBox(height: KSpace.md),
                CompactFigure(figure: fig, language: lang, height: 200),
              ],
              const SizedBox(height: KSpace.lg),
              OptionGrid(
                count: options.length,
                withFigures: question.optionFigures.isNotEmpty,
                itemBuilder: (context, i) => _OptionTile(
                  letter: String.fromCharCode(65 + i),
                  text: options[i],
                  style: style,
                  figure: i < question.optionFigures.length
                      ? question.optionFigures[i]
                      : null,
                  state: answered == null
                      ? _OptionState.idle
                      : i == question.correctIndex
                      ? _OptionState.right
                      : i == answered
                      ? _OptionState.wrong
                      : _OptionState.dim,
                  onTap: answered == null ? () => onChoose(i) : null,
                ),
              ),
              if (answered != null) ...[
                const SizedBox(height: KSpace.sm),
                _Feedback(
                  correct: correct,
                  explanation: question.explanation,
                  style: style,
                ),
                const SizedBox(height: KSpace.lg),
                FilledButton(
                  onPressed: onNext,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
                    child: Text(
                      index + 1 >= total ? l10n.quizSeeResults : l10n.quizNext,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _OptionState { idle, right, wrong, dim }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.style,
    required this.state,
    required this.onTap,
    this.figure,
  });

  final String letter;
  final String text;
  final BlockStyle style;
  final _OptionState state;
  final VoidCallback? onTap;
  final Map<String, dynamic>? figure;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final color = switch (state) {
      _OptionState.right => kc.success,
      _OptionState.wrong => kc.danger,
      _ => kc.border,
    };
    final icon = switch (state) {
      _OptionState.right => Icons.check_circle_rounded,
      _OptionState.wrong => Icons.cancel_rounded,
      _ => null,
    };
    return Opacity(
      opacity: state == _OptionState.dim ? 0.55 : 1,
      child: Material(
        color: state == _OptionState.idle || state == _OptionState.dim
            ? kc.surface
            : color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.chip),
          side: BorderSide(color: color, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (figure case final fig?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KSpace.sm),
                    child: CompactFigure(
                      figure: fig,
                      language: style.language,
                      height: 96,
                      showCaption: false,
                      zoomButton: true,
                    ),
                  ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: kc.surfaceRaised,
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: kc.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpace.md),
                    Expanded(
                      child: Directionality(
                        textDirection: style.direction,
                        child: RichBlockText(text: text, style: style),
                      ),
                    ),
                    if (icon != null) Icon(icon, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.correct,
    required this.explanation,
    required this.style,
  });

  final bool correct;
  final String explanation;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final color = correct ? kc.success : kc.danger;
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? l10n.quizCorrect : l10n.quizWrong,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: KSpace.xs),
            Directionality(
              textDirection: style.direction,
              child: RichBlockText(text: explanation, style: style),
            ),
          ],
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.correct,
    required this.total,
    required this.onFinish,
  });

  final int correct;
  final int total;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final ratio = total == 0 ? 0.0 : correct / total;
    final color = ratio >= 0.7
        ? kc.success
        : (ratio >= 0.4 ? kc.warning : kc.danger);
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpace.xl),
            child: MaxWidth(
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 10,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.15),
                          ),
                        ),
                        Text(
                          '${(ratio * 100).round()}%',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KSpace.lg),
                  Text(
                    l10n.quizScore(correct, total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (correct < total) ...[
                    const SizedBox(height: KSpace.sm),
                    Text(
                      l10n.quizCardsBack,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kc.textSecondary),
                    ),
                  ],
                  const SizedBox(height: KSpace.xl),
                  FilledButton(
                    onPressed: onFinish,
                    child: Text(l10n.quizFinish),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}
