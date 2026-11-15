import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/motivation/motivation_providers.dart';
import '../../data/motivation/motivation_store.dart';
import '../../data/reminders/reminder_controller.dart';
import '../../data/reminders/reminder_state.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/step_layout.dart';
import 'reminder_form.dart';

/// Onboarding, after year / semester: "When do you want to study?".
/// Allow = save (queued if offline) + ask the Android 13+ permission.
/// Skip = nothing changes.
class ReminderStep extends ConsumerStatefulWidget {
  const ReminderStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ReminderStep> createState() => _ReminderStepState();
}

class _ReminderStepState extends ConsumerState<ReminderStep> {
  late String _time;
  late List<int> _days;
  bool _busy = false;
  StudyAnchor? _anchor;

  void _pickAnchor(StudyAnchor a) {
    final t = anchorTime(a, DateTime.now());
    setState(() {
      _anchor = a;
      if (t != null) _time = t;
    });
  }

  Future<void> _saveAnchor() async {
    if (_anchor != null) {
      await ref.read(motivationStoreProvider).setAnchor(_anchor!);
    }
  }

  @override
  void initState() {
    super.initState();
    final saved = ref.read(reminderControllerProvider);
    _time = saved?.studyTime ?? defaultStudyTime;
    _days = saved?.studyDays ?? everyDay;
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    await _saveAnchor();
    final reminders = ref.read(reminderControllerProvider.notifier);
    await reminders.updateSettings(enabled: true, time: _time, days: _days);
    await reminders.requestPermission();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.lg),
        Icon(Icons.alarm_rounded, size: 64, color: kc.accentText),
        const SizedBox(height: KSpace.lg),
        Text(
          l10n.reminderStepTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KSpace.md),
        Text(
          l10n.reminderStepBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: kc.textSecondary),
        ),
        const SizedBox(height: KSpace.md),
        // MOT-1: tie studying to something that already happens every day.
        Text(
          l10n.anchorTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: KSpace.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: KSpace.xs,
          runSpacing: KSpace.xs,
          children: [
            for (final a in StudyAnchor.values)
              ChoiceChip(
                label: Text(switch (a) {
                  StudyAnchor.afterSchool => l10n.anchorAfterSchool,
                  StudyAnchor.afterMaghrib => l10n.anchorAfterMaghrib,
                  StudyAnchor.afterIsha => l10n.anchorAfterIsha,
                  StudyAnchor.afterDinner => l10n.anchorAfterDinner,
                  StudyAnchor.beforeSleep => l10n.anchorBeforeSleep,
                  StudyAnchor.custom => l10n.anchorCustom,
                }),
                selected: _anchor == a,
                onSelected: (_) => _pickAnchor(a),
              ),
          ],
        ),
        const SizedBox(height: KSpace.md),
        ReminderForm(
          time: _time,
          days: _days,
          onTime: (t) => setState(() {
            _time = t;
            _anchor = StudyAnchor.custom;
          }),
          onDays: (d) => setState(() => _days = d),
        ),
      ],
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _allow,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(l10n.reminderAllow),
          ),
          TextButton(
            onPressed: _busy ? null : widget.onDone,
            child: Text(l10n.reminderSkip),
          ),
        ],
      ),
    );
  }
}
