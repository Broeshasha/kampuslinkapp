import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/reminders/reminder_controller.dart';
import '../../data/reminders/reminder_notifier.dart';
import '../../data/reminders/reminder_state.dart';
import '../../data/reminders/reminder_texts.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import 'reminder_form.dart';

/// Test builds only: one reminder in a minute, outside the planned ids so
/// the next re-plan does not cancel it.
const _testReminderId = 7199;

String _summary(BuildContext context, ReminderState? s) {
  final l10n = AppLocalizations.of(context);
  if (s == null || !s.enabled) {
    return l10n.remindersOff;
  }
  final days = s.studyDays.length == 7
      ? ''
      : ' \u00b7 ${[for (final d in s.studyDays) reminderDayName(context, d)].join(', ')}';
  return '${reminderTimeText(context, s.studyTime)}$days';
}

/// Profile row: opens Profile > Reminders.
class RemindersTile extends ConsumerWidget {
  const RemindersTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(reminderControllerProvider);
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: Text(l10n.remindersTitle),
      subtitle: Text(_summary(context, state)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/profile/reminders'),
    );
  }
}

/// Profile > Reminders: on/off, time, days; the next planned reminder; why
/// they stopped; how to turn notifications on (permission, battery).
class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage>
    with WidgetsBindingObserver {
  bool? _granted;
  DateTime? _next;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone settings: check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  DateTime? _nextPlanned() {
    final now = DateTime.now();
    DateTime? best;
    for (final s
        in ref.read(sharedPrefsProvider).getStringList(reminderPlanKey) ??
            const <String>[]) {
      final at = DateTime.tryParse(s);
      if (at != null &&
          at.isAfter(now) &&
          (best == null || at.isBefore(best))) {
        best = at;
      }
    }
    return best?.toLocal();
  }

  Future<void> _check() async {
    final granted = await ref
        .read(reminderControllerProvider.notifier)
        .permissionGranted();
    if (mounted) {
      setState(() {
        _granted = granted;
        _next = _nextPlanned();
      });
    }
  }

  Future<void> _ask() async {
    final granted = await ref
        .read(reminderControllerProvider.notifier)
        .requestPermission();
    if (mounted) {
      setState(() {
        _granted = granted;
        _next = _nextPlanned();
      });
    }
  }

  Future<void> _update(
    ReminderState s, {
    bool? enabled,
    String? time,
    List<int>? days,
  }) async {
    await ref
        .read(reminderControllerProvider.notifier)
        .updateSettings(
          enabled: enabled ?? s.enabled,
          time: time ?? s.studyTime,
          days: days ?? s.studyDays,
        );
    if (mounted) {
      setState(() => _next = _nextPlanned());
    }
  }

  /// Test builds only.
  Future<void> _sendTest() async {
    final messenger = ScaffoldMessenger.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final at = DateTime.now().toUtc().add(const Duration(minutes: 1));
    final texts = reminderTexts(lang);
    final r = await guard(() async {
      await ref.read(reminderControllerProvider.notifier).permissionGranted();
      await ref.read(reminderNotifierProvider).schedule([
        ReminderSlot(
          id: _testReminderId,
          at: at,
          body: texts.generic,
          payload: at.toIso8601String(),
        ),
      ], texts);
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          r is Ok ? 'Test reminder in about 1 minute' : 'Test reminder failed',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final s = ref.watch(reminderControllerProvider) ?? const ReminderState();
    final paused =
        s.active &&
        s.pausedUntil != null &&
        s.pausedUntil!.isAfter(DateTime.now());
    final next = _next;
    final secondary = TextStyle(color: kc.textSecondary);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.remindersTitle),
                  value: s.enabled && !s.stopped,
                  onChanged: (on) async {
                    await _update(s, enabled: on);
                    if (on && _granted == false) {
                      await _ask();
                    }
                  },
                ),
                if (s.stopped && s.enabled)
                  Text(l10n.remindersStoppedNote, style: secondary),
                if (paused) Text(l10n.remindersPausedNote, style: secondary),
                if (s.enabled && !s.stopped) ...[
                  const SizedBox(height: KSpace.md),
                  ReminderForm(
                    time: s.studyTime,
                    days: s.studyDays,
                    onTime: (t) => _update(s, time: t),
                    onDays: (d) => _update(s, days: d),
                  ),
                  const SizedBox(height: KSpace.md),
                  Text(
                    next == null
                        ? l10n.remindersNextNone
                        : l10n.remindersNext(
                            DateFormat.MMMEd(lang).add_Hm().format(next),
                          ),
                    style: TextStyle(
                      color: kc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: KSpace.sm),
                  Text(l10n.remindersBatteryTip, style: secondary),
                ],
                if (_granted == false) ...[
                  const SizedBox(height: KSpace.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                color: kc.textSecondary,
                              ),
                              const SizedBox(width: KSpace.sm),
                              Expanded(child: Text(l10n.remindersDeniedHint)),
                            ],
                          ),
                          const SizedBox(height: KSpace.sm),
                          OutlinedButton(
                            onPressed: _ask,
                            child: Text(l10n.reminderAllow),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!kReleaseMode) ...[
                  const SizedBox(height: KSpace.xl),
                  OutlinedButton.icon(
                    onPressed: _sendTest,
                    icon: const Icon(Icons.bug_report_outlined),
                    // Test builds only (never in the Play Store build).
                    label: const Text('Send a test reminder in 1 minute'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
