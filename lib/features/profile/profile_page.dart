import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/result.dart';
import '../../core/logging/logger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/theme/tokens.dart';
import '../../data/learning/feed_repository.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../render/reader_settings.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../auth/google_sign_in_button.dart';
import 'account_actions.dart';
import 'language_picker.dart';

/// Where "Send feedback" writes to. Change it here only.
const feedbackEmail = 'chidafarai06@gmail.com';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (error) {
    appLog.info('version unavailable: $error');
    return '';
  }
});

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Profile tab: who you are, your numbers, saved cards, settings, account.
/// Signed out: sign-in + device settings only (nothing touches the DB).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    final sections = <Widget>[
      if (signedIn) ...[
        const _AccountHeader(),
        const SizedBox(height: KSpace.lg),
        const _StatsGrid(),
        const SizedBox(height: KSpace.lg),
        const _SavedCardsRow(),
      ] else
        const _SignedOutHeader(),
      const SizedBox(height: KSpace.xl),
      _SectionTitle(l10n.settingsTitle),
      const _SettingsCard(),
      if (signedIn) ...[const SizedBox(height: KSpace.md), const _SyncRow()],
      const SizedBox(height: KSpace.xl),
      _SectionTitle(l10n.aboutTitle),
      const _AboutCard(),
      if (signedIn) ...[
        const SizedBox(height: KSpace.xl),
        const _AccountActions(),
      ],
      if (kDebugMode) ...[
        const SizedBox(height: KSpace.lg),
        TextButton(
          onPressed: () => context.go('/profile/states'),
          child: const Text('UI states (debug)'),
        ),
        TextButton(
          onPressed: () => context.go('/profile/renderer'),
          child: const Text('Renderer preview (debug)'),
        ),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KSpace.lg,
          KSpace.sm,
          KSpace.lg,
          KSpace.xxl * 3,
        ),
        children: [for (final s in sections) MaxWidth(child: s)],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: KSpace.xs,
      bottom: KSpace.sm,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: context.kc.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.card),
        side: BorderSide(color: kc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SignedOutHeader extends StatelessWidget {
  const _SignedOutHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: KSpace.lg),
        Icon(Icons.badge_outlined, size: 56, color: context.kc.accentText),
        const SizedBox(height: KSpace.md),
        Text(
          l10n.profilePlaceholder,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: KSpace.lg),
        const GoogleSignInButton(),
      ],
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final stats = switch (ref.watch(serverStatsProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final email = switch (ref.watch(sessionProvider)) {
      AsyncData(:final value) => value?.user.email ?? '',
      _ => '',
    };
    final username = '${stats?['username'] ?? ''}';
    final name = username.isNotEmpty ? '@$username' : email;
    final details = [
      stats?['university_name'],
      stats?['speciality_name'],
      stats?['academic_year'],
    ].where((v) => v != null && '$v'.isNotEmpty).join(' \u00b7 ');
    final initial = (username.isNotEmpty ? username : email).isEmpty
        ? '?'
        : (username.isNotEmpty ? username : email)
              .substring(0, 1)
              .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.card),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            kc.accent.withValues(alpha: 0.30),
            kc.accentAlt.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: kc.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: kc.accentGradient,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kc.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final stats = switch (ref.watch(serverStatsProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final days = switch (ref.watch(studyDaysProvider)) {
      AsyncData(:final value) => value,
      _ => const <String, int>{},
    };
    final done = switch (ref.watch(lessonsDoneProvider)) {
      AsyncData(:final value) => value,
      _ => 0,
    };
    final serverStreak = stats?['current_streak'];
    final streak = serverStreak == null
        ? localStreak(days, DateTime.now())
        : _int(serverStreak);
    final minutes = days.values.fold<int>(0, (a, b) => a + b) ~/ 60;
    final tiles = [
      _StatTile(
        icon: Icons.local_fire_department_rounded,
        color: kc.streak,
        value: '$streak',
        label: l10n.streakLabel,
      ),
      _StatTile(
        icon: Icons.bolt_rounded,
        color: kc.xp,
        value: '${_int(stats?['xp'])}',
        label: l10n.xpLabel,
      ),
      _StatTile(
        icon: Icons.timer_outlined,
        color: kc.accentText,
        value: '$minutes',
        label: l10n.minutesStudied,
      ),
      _StatTile(
        icon: Icons.task_alt_rounded,
        color: kc.success,
        value: '$done',
        label: l10n.lessonsDoneLabel,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 520 ? 4 : 2;
        final width =
            (constraints.maxWidth - KSpace.sm * (perRow - 1)) / perRow;
        return Wrap(
          spacing: KSpace.sm,
          runSpacing: KSpace.sm,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: kc.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kc.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCardsRow extends ConsumerWidget {
  const _SavedCardsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final count = switch (ref.watch(savedCardsProvider)) {
      AsyncData(:final value) => value.length,
      _ => 0,
    };
    return _Card(
      children: [
        ListTile(
          leading: Icon(Icons.bookmark_rounded, color: kc.xp),
          title: Text(l10n.savedCards),
          trailing: Text(
            '$count',
            style: TextStyle(
              color: kc.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => context.go('/profile/saved'),
        ),
      ],
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final mode = ref.watch(themeModeProvider);
    final step = ref.watch(readerScaleStepProvider);
    final signedIn = ref.watch(isSignedInProvider);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Text(text, style: TextStyle(color: kc.textSecondary)),
    );
    return _Card(
      children: [
        Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(l10n.languageLabel),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: LanguagePicker(),
              ),
              const SizedBox(height: KSpace.lg),
              label(l10n.themeLabel),
              Wrap(
                spacing: KSpace.sm,
                runSpacing: KSpace.sm,
                children: [
                  for (final (m, text) in [
                    (ThemeMode.system, l10n.themeSystem),
                    (ThemeMode.light, l10n.themeLight),
                    (ThemeMode.dark, l10n.themeDark),
                  ])
                    ChoiceChip(
                      label: Text(text),
                      selected: mode == m,
                      onSelected: (_) =>
                          ref.read(themeModeProvider.notifier).set(m),
                    ),
                ],
              ),
              const SizedBox(height: KSpace.lg),
              label(l10n.readerTextSize),
              Wrap(
                spacing: KSpace.sm,
                runSpacing: KSpace.sm,
                children: [
                  for (final (s, text) in [(0, 'A-'), (1, 'A'), (2, 'A+')])
                    ChoiceChip(
                      label: Text(text),
                      selected: step == s,
                      onSelected: (_) =>
                          ref.read(readerScaleStepProvider.notifier).setStep(s),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (signedIn) ...[
          Divider(height: 1, color: kc.border),
          const _RemindersSwitch(),
        ],
      ],
    );
  }
}

class _RemindersSwitch extends ConsumerStatefulWidget {
  const _RemindersSwitch();

  @override
  ConsumerState<_RemindersSwitch> createState() => _RemindersSwitchState();
}

class _RemindersSwitchState extends ConsumerState<_RemindersSwitch> {
  bool? _value;
  bool _busy = false;

  Future<void> _set(bool on) async {
    final api = ref.read(kampusApiProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (api == null || !ref.read(isOnlineProvider)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOffline)));
      return;
    }
    final before = _value;
    setState(() {
      _value = on;
      _busy = true;
    });
    final result = await guard(() => api.setReminders(enabled: on));
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Err(:final failure)) {
      setState(() => _value = before);
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stats = switch (ref.watch(serverStatsProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final value = _value ?? (stats?['reminders_enabled'] == true);
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: Text(l10n.remindersLabel),
      value: value,
      onChanged: _busy ? null : _set,
    );
  }
}

class _SyncRow extends ConsumerWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final pending = switch (ref.watch(pendingOpsProvider)) {
      AsyncData(:final value) => value,
      _ => 0,
    };
    return Row(
      children: [
        Icon(
          pending == 0
              ? Icons.cloud_done_outlined
              : Icons.cloud_upload_outlined,
          size: 18,
          color: kc.textSecondary,
        ),
        const SizedBox(width: KSpace.sm),
        Expanded(
          child: Text(
            pending == 0 ? l10n.allSynced : l10n.pendingSync(pending),
            style: TextStyle(color: kc.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final version = switch (ref.watch(appVersionProvider)) {
      AsyncData(:final value) => value,
      _ => '',
    };
    return _Card(
      children: [
        ListTile(
          leading: Icon(Icons.mail_outline_rounded, color: kc.accentText),
          title: Text(l10n.sendFeedback),
          onTap: () => launchUrl(
            Uri(
              scheme: 'mailto',
              path: feedbackEmail,
              query:
                  'subject=${Uri.encodeComponent('KampusLink feedback $version')}',
            ),
          ),
        ),
        Divider(height: 1, color: kc.border),
        ListTile(
          leading: Icon(Icons.info_outline_rounded, color: kc.textSecondary),
          title: Text(l10n.appVersion(version.isEmpty ? '-' : version)),
        ),
      ],
    );
  }
}

class _AccountActions extends ConsumerWidget {
  const _AccountActions();

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteDialog(),
    );
    if (ok != true) return;
    final failure = await deleteAccount(ref);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? l10n.deleteAccountDone
              : failureMessage(l10n, failure),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => signOutEverywhere(ref),
          icon: const Icon(Icons.logout_rounded),
          label: Text(l10n.signOut),
        ),
        const SizedBox(height: KSpace.sm),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: kc.danger),
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.deleteAccount),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: kc.danger),
      title: Text(l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountBody),
            const SizedBox(height: KSpace.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: Text(l10n.deleteAccountCheck),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kc.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.deleteAccountConfirm),
        ),
      ],
    );
  }
}
