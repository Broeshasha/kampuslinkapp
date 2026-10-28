import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
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

  @override
  void initState() {
    super.initState();
    final saved = ref.read(reminderControllerProvider);
    _time = saved?.studyTime ?? defaultStudyTime;
    _days = saved?.studyDays ?? everyDay;
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
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
        const SizedBox(height: KSpace.lg),
        ReminderForm(
          time: _time,
          days: _days,
          onTime: (t) => setState(() => _time = t),
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
