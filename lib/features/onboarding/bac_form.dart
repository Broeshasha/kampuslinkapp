import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart';
import '../../data/profile/offers.dart';
import '../../data/profile/study_level.dart';
import '../../data/profile/waitlist_check.dart';
import '../../data/profile/wilayas.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/legal_links.dart';
import '../../ui/states.dart';
import 'onboarding_status.dart';
import 'step_layout.dart';

/// BAC-2: stream (SE selectable, the others "coming soon" + Notify me)
/// -> year (3AS) -> wilaya (required, searchable) -> consent line -> Start.
/// No school, no birth date, no free-text identity (a username is made by
/// the server).
class BacForm extends ConsumerStatefulWidget {
  const BacForm({super.key, required this.offers, required this.onDone});

  final OnboardingOffers offers;
  final VoidCallback onDone;

  @override
  ConsumerState<BacForm> createState() => _BacFormState();
}

class _BacFormState extends ConsumerState<BacForm> {
  String? _stream;
  String? _year;
  int? _wilaya;
  bool _busy = false;
  final _notified = <String>{};
  final _username = TextEditingController();
  String? _usernameError;
  static final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final active = widget.offers.bacStreams.where((s) => s.active).toList();
    if (active.length == 1) _stream = active.first.code;
    if (widget.offers.bacYears.length == 1) {
      _year = widget.offers.bacYears.first.year;
    }
  }

  Future<void> _notify(BacStream s) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(studiesApiProvider);
    if (api == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOffline)));
      return;
    }
    final r = await guard(
      () => api.joinWaitlist(specialityId: s.id, year: _year ?? '3AS'),
    );
    if (!mounted) return;
    switch (r) {
      case Ok():
        setState(() => _notified.add(s.code));
        messenger.showSnackBar(SnackBar(content: Text(l10n.bacNotified)));
      case Err(:final failure):
        messenger.showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, failure))),
        );
    }
  }

  void _otherStreams(String lang) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(KSpace.md),
          children: [
            Text(
              l10n.bacOtherStreamsSoon,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            for (final s in widget.offers.bacStreams)
              if (!s.active)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.label(lang)),
                  trailing: _notified.contains(s.code)
                      ? const Icon(Icons.check_rounded)
                      : TextButton(
                          onPressed: () async {
                            await _notify(s);
                            setSheet(() {});
                          },
                          child: Text(l10n.bacNotifyMe),
                        ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final stream = _stream;
    final year = _year;
    final wilaya = _wilaya;
    if (stream == null || year == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.studiesChooseSpeciality)),
      );
      return;
    }
    if (wilaya == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.wilayaRequired)));
      return;
    }
    // Founder decision: bac students choose their username (their identity).
    final username = _username.text.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(username)) {
      setState(() => _usernameError = l10n.usernameHelp);
      return;
    }
    final api = ref.read(kampusApiProvider);
    if (api == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorServer)));
      return;
    }
    setState(() => _busy = true);
    final result = await guard(
      () => api.setBacProfile(
        stream: stream,
        year: year,
        wilaya: wilaya,
        language: language,
        username: username,
      ),
    );
    if (result is Ok) {
      await ref.read(studyLevelProvider.notifier).save(year, null);
      await ref.read(sharedPrefsProvider).remove(waitlistKey);
      await cancelWaitlistCheck();
      ref.invalidate(catalogProvider);
      ref.invalidate(meProvider);
    }
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
        } else if (failure is ValidationFailure &&
            failure.code == 'not_offered') {
          ref.invalidate(onboardingOptionsProvider);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.studiesNotOffered)),
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
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context).textTheme;
    final label = theme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.md),
        Text(
          l10n.trackBac,
          style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KSpace.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l10n.bacStreamLabel, style: label),
        ),
        const SizedBox(height: KSpace.sm),
        RadioGroup<String>(
          groupValue: _stream,
          onChanged: (v) => setState(() => _stream = v),
          child: Column(
            children: [
              // Only the streams that are open. The others: one quiet line.
              for (final s in widget.offers.bacStreams)
                if (s.active)
                  RadioListTile<String>(
                    value: s.code,
                    title: Text(s.label(lang)),
                    contentPadding: EdgeInsets.zero,
                  ),
            ],
          ),
        ),
        if (widget.offers.bacStreams.any((s) => !s.active))
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.bacOtherStreamsSoon,
                  style: theme.bodySmall?.copyWith(color: kc.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => _otherStreams(lang),
                child: Text(l10n.bacNotifyMe),
              ),
            ],
          ),
        const SizedBox(height: KSpace.md),
        if (widget.offers.bacYears.length > 1) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.bacYearLabel, style: label),
          ),
          const SizedBox(height: KSpace.sm),
          Wrap(
            spacing: KSpace.sm,
            children: [
              for (final y in widget.offers.bacYears)
                ChoiceChip(
                  label: Text(y.labelIn(lang)),
                  selected: _year == y.year,
                  onSelected: (_) => setState(() => _year = y.year),
                ),
            ],
          ),
          const SizedBox(height: KSpace.md),
        ],
        DropdownMenu<int>(
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          label: Text(l10n.wilayaLabel),
          helperText: l10n.wilayaWhy,
          menuHeight: 320,
          onSelected: (v) => setState(() => _wilaya = v),
          dropdownMenuEntries: [
            for (final w in wilayas)
              DropdownMenuEntry<int>(
                value: w.code,
                label: '${w.code} - ${lang == 'ar' ? w.ar : w.fr}',
              ),
          ],
        ),
        const SizedBox(height: KSpace.md),
        TextField(
          controller: _username,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.usernameLabel,
            helperText: l10n.usernameHelp,
            errorText: _usernameError,
          ),
          onChanged: (_) {
            if (_usernameError != null) setState(() => _usernameError = null);
          },
        ),
        const SizedBox(height: KSpace.lg),
        Text(
          l10n.bacConsent,
          textAlign: TextAlign.center,
          style: theme.bodySmall?.copyWith(color: kc.textSecondary),
        ),
        const LegalLinksLine(),
      ],
      action: FilledButton(
        onPressed: _busy ? null : _start,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.bacStart),
      ),
    );
  }
}

/// "University or Bac?" - the first studies question.
class TrackChoice extends StatelessWidget {
  const TrackChoice({super.key, required this.onChoose});

  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    Widget option(IconData icon, String text, String value) => Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(text, style: theme.titleMedium),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => onChoose(value),
      ),
    );
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.xxl),
        Text(
          l10n.trackQuestion,
          style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KSpace.xl),
        option(Icons.account_balance_rounded, l10n.trackUniversity, 'univ'),
        const SizedBox(height: KSpace.sm),
        option(Icons.school_rounded, l10n.trackBac, 'bac'),
      ],
      action: const SizedBox.shrink(),
    );
  }
}
