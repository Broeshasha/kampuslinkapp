import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';
import 'onboarding_status.dart';
import 'step_layout.dart';

/// Step 3: locked to Mining Engineering L2 for the pilot (D-004).
class StudiesStep extends ConsumerStatefulWidget {
  const StudiesStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<StudiesStep> createState() => _StudiesStepState();
}

class _StudiesStepState extends ConsumerState<StudiesStep> {
  static const _pilotSpeciality = 2;
  static const _pilotYear = 'L2';
  static final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

  final _username = TextEditingController();
  int? _universityId;
  int _goal = 30;
  bool _reminders = true;
  TimeOfDay _reminderAt = const TimeOfDay(hour: 20, minute: 0);
  bool _notifyMe = false;
  bool _prefilled = false;
  bool _busy = false;
  String? _usernameError;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  String _suggestUsername(String email) {
    var name = email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (name.length < 3) name = 'student$name';
    return name.length > 20 ? name.substring(0, 20) : name;
  }

  void _prefill(Map<String, dynamic>? me) {
    if (_prefilled) return;
    _prefilled = true;
    final prefs = ref.read(sharedPrefsProvider);
    _notifyMe = prefs.getBool('notify_more_specialities') ?? false;
    final saved = me?['username']?.toString() ?? '';
    final email = ref.read(authRepositoryProvider).session?.user.email ?? '';
    _username.text = _usernamePattern.hasMatch(saved)
        ? saved
        : _suggestUsername(email);
    final uni = me?['university_id'];
    _universityId = uni is num ? uni.toInt() : null;
    final goal = me?['study_goal_minutes'];
    if (goal is num && goal > 0) _goal = goal.toInt().clamp(10, 120);
    final reminders = me?['reminders_enabled'];
    if (reminders is bool) _reminders = reminders;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderAt,
    );
    if (picked != null && mounted) setState(() => _reminderAt = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final username = _username.text.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(username)) {
      setState(() => _usernameError = l10n.usernameHelp);
      return;
    }
    final universityId = _universityId;
    if (universityId == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.chooseUniversity)));
      return;
    }
    final api = ref.read(kampusApiProvider);
    if (api == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorServer)));
      return;
    }
    setState(() => _busy = true);
    final prefs = ref.read(sharedPrefsProvider);
    final result = await guard<void>(() async {
      await api.completeOnboarding(
        username: username,
        universityId: universityId,
        specialityId: _pilotSpeciality,
        academicYear: _pilotYear,
        language: language,
      );
      await api.setStudyGoal(_goal);
      await api.setReminders(enabled: _reminders);
      await prefs.setString(
        'reminder_time',
        '${_reminderAt.hour.toString().padLeft(2, '0')}:'
            '${_reminderAt.minute.toString().padLeft(2, '0')}',
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        widget.onDone();
      case Err(:final failure):
        if (failure is ValidationFailure &&
            (failure.code == 'username_taken' ||
                failure.code == 'invalid_username')) {
          setState(
            () => _usernameError = failure.code == 'username_taken'
                ? l10n.usernameTaken
                : l10n.usernameHelp,
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(failureMessage(l10n, failure))),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(onboardingOptionsProvider);
    final me = ref.watch(meProvider);
    return switch ((options, me)) {
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => ErrorView(
        failure: mapError(error),
        onRetry: () {
          ref.invalidate(onboardingOptionsProvider);
          ref.invalidate(meProvider);
        },
      ),
      (AsyncData(value: final opts), AsyncData(value: final meValue)) => _form(
        context,
        opts,
        meValue,
      ),
      _ => const LoadingView(),
    };
  }

  List<Map<String, dynamic>> _list(Object? v) => [
    for (final e in (v is List ? v : const <Object?>[]))
      if (e is Map) e.cast<String, dynamic>(),
  ];

  Widget _form(
    BuildContext context,
    Map<String, dynamic> options,
    Map<String, dynamic>? me,
  ) {
    _prefill(me);
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final universities = _list(options['universities']);
    final others = [
      for (final s in _list(options['specialities']))
        if ((s['id'] as num?)?.toInt() != _pilotSpeciality) '${s['name']}',
    ];
    final selected =
        universities.any((u) => (u['id'] as num?)?.toInt() == _universityId)
        ? _universityId
        : null;
    final title = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.md),
        Text(l10n.onboardingStudiesTitle, style: title),
        const SizedBox(height: KSpace.lg),
        _PilotCard(label: l10n.studiesPilot),
        const SizedBox(height: KSpace.sm),
        _ComingSoonCard(
          title: l10n.studiesComingSoon,
          names: others.take(3).join(' \u00b7 '),
          notifyLabel: l10n.studiesNotifyMe,
          notify: _notifyMe,
          onNotify: (v) {
            setState(() => _notifyMe = v);
            ref
                .read(sharedPrefsProvider)
                .setBool('notify_more_specialities', v);
          },
        ),
        const SizedBox(height: KSpace.lg),
        DropdownButtonFormField<int>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.universityLabel,
            hintText: l10n.chooseUniversity,
          ),
          items: [
            for (final u in universities)
              DropdownMenuItem<int>(
                value: (u['id'] as num).toInt(),
                child: Text('${u['name']}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _universityId = v),
        ),
        const SizedBox(height: KSpace.md),
        TextField(
          controller: _username,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.usernameLabel,
            helperText: l10n.usernameHelp,
            helperMaxLines: 2,
            errorText: _usernameError,
            prefixText: '@',
          ),
          onChanged: (_) {
            if (_usernameError != null) setState(() => _usernameError = null);
          },
        ),
        const SizedBox(height: KSpace.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l10n.studyGoalLabel(_goal)),
        ),
        Slider(
          value: _goal.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          label: '$_goal',
          onChanged: (v) => setState(() => _goal = v.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _reminders,
          onChanged: (v) => setState(() => _reminders = v),
          title: Text(l10n.remindersLabel),
        ),
        if (_reminders)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(l10n.reminderTime(_reminderAt.format(context))),
            ),
          ),
        const SizedBox(height: KSpace.lg),
        Text(' ', style: TextStyle(color: kc.textSecondary)),
      ],
      action: FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.onboardingFinishStudies),
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kc.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KRadius.card),
        border: Border.all(color: kc.accent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Row(
          children: [
            Icon(Icons.terrain_rounded, color: kc.accentText, size: 32),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.check_circle, color: kc.accentText),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.title,
    required this.names,
    required this.notifyLabel,
    required this.notify,
    required this.onNotify,
  });

  final String title;
  final String names;
  final String notifyLabel;
  final bool notify;
  final ValueChanged<bool> onNotify;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: BorderRadius.circular(KRadius.card),
        border: Border.all(color: kc.border),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          KSpace.lg,
          KSpace.md,
          KSpace.sm,
          KSpace.md,
        ),
        child: Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: kc.textSecondary),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: kc.textPrimary)),
                  if (names.isNotEmpty)
                    Text(
                      names,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kc.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: notify, onChanged: onNotify),
                Text(
                  notifyLabel,
                  style: TextStyle(color: kc.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
