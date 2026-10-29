import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart';
import '../../data/profile/offers.dart';
import '../../data/profile/study_level.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';
import '../profile/account_actions.dart';
import 'onboarding_status.dart';
import 'step_layout.dart';

/// Step 3 "Your studies": university -> speciality -> year -> semester,
/// ALL from get_onboarding_options() (only what is offered). Not listed ->
/// waitlist -> "Coming soon" (shown again at the next start while the
/// speciality is still not offered).
class StudiesStep extends ConsumerStatefulWidget {
  const StudiesStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<StudiesStep> createState() => _StudiesStepState();
}

enum _View { form, waitlist, comingSoon }

class _StudiesStepState extends ConsumerState<StudiesStep> {
  static final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

  final _username = TextEditingController();
  final _otherName = TextEditingController();
  final _otherYear = TextEditingController();
  int? _universityId;
  int? _specialityId;
  String? _year;
  int? _semester;
  int? _otherId;
  int _goal = 30;
  bool _prefilled = false;
  bool _busy = false;
  String? _usernameError;
  _View? _view;

  @override
  void dispose() {
    _username.dispose();
    _otherName.dispose();
    _otherYear.dispose();
    super.dispose();
  }

  String _suggestUsername(String email) {
    var name = email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (name.length < 3) {
      name = 'student$name';
    }
    return name.length > 20 ? name.substring(0, 20) : name;
  }

  void _prefill(OnboardingOffers offers, Map<String, dynamic>? me) {
    if (_prefilled) {
      return;
    }
    _prefilled = true;
    final saved = me?['username']?.toString() ?? '';
    final email = ref.read(authControllerProvider).email ?? '';
    _username.text = _usernamePattern.hasMatch(saved)
        ? saved
        : _suggestUsername(email);
    final uni = me?['university_id'];
    _universityId = uni is num ? uni.toInt() : null;
    final goal = me?['study_goal_minutes'];
    if (goal is num && goal > 0) {
      _goal = goal.toInt().clamp(10, 120);
    }
    // Pre-select: the waitlisted speciality now offered, else the profile,
    // else the only offered one.
    final waitlist = readWaitlist(ref.read(sharedPrefsProvider));
    final mine = me?['speciality_id'];
    final wanted =
        waitlist?.specialityId ?? (mine is num ? mine.toInt() : null);
    final speciality =
        offers.speciality(wanted) ??
        (offers.specialities.length == 1 ? offers.specialities.first : null);
    if (speciality != null) {
      _choose(speciality, waitlist?.year ?? me?['academic_year']?.toString());
    }
    _universityId ??= waitlist?.universityId;
    _view =
        offers.waitlisted &&
            !offers.offers(waitlist?.specialityId, waitlist?.year)
        ? _View.comingSoon
        : _View.form;
  }

  void _choose(OfferedSpeciality s, [String? year]) {
    _specialityId = s.id;
    final level = s.level(year) ?? (s.levels.isEmpty ? null : s.levels.first);
    _year = level?.year;
    _semester = (level?.semesters.isNotEmpty ?? false)
        ? level!.semesters.first
        : null;
  }

  Future<void> _submit(OnboardingOffers offers) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final username = _username.text.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(username)) {
      setState(() => _usernameError = l10n.usernameHelp);
      return;
    }
    final universityId = _universityId;
    final specialityId = _specialityId;
    final year = _year;
    if (universityId == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.chooseUniversity)));
      return;
    }
    if (specialityId == null || year == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.studiesChooseSpeciality)),
      );
      return;
    }
    final api = ref.read(kampusApiProvider);
    if (api == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorServer)));
      return;
    }
    setState(() => _busy = true);
    final result = await guard<void>(() async {
      await api.completeOnboarding(
        username: username,
        universityId: universityId,
        specialityId: specialityId,
        academicYear: year,
        language: language,
      );
      await api.setStudyGoal(_goal);
    });
    if (result is Ok) {
      await ref.read(studyLevelProvider.notifier).save(year, _semester);
      await ref.read(sharedPrefsProvider).remove(waitlistKey);
      ref.invalidate(catalogProvider);
    }
    if (!mounted) {
      return;
    }
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

  Future<void> _joinWaitlist(OnboardingOffers offers) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final typed = _otherName.text.trim();
    final other = [
      for (final o in offers.others)
        if (o.id == _otherId) o,
    ];
    final name = other.isNotEmpty ? other.first.name : typed;
    if (name.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.studiesChooseSpeciality)),
      );
      return;
    }
    final api = ref.read(studiesApiProvider);
    if (api == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOffline)));
      return;
    }
    final year = _otherYear.text.trim();
    final entry = WaitlistEntry(
      specialityId: other.isNotEmpty ? other.first.id : null,
      specialityText: other.isNotEmpty ? null : typed,
      year: year.isEmpty ? null : year,
      universityId: _universityId,
      name: name,
    );
    setState(() => _busy = true);
    final result = await guard(
      () => api.joinWaitlist(
        specialityId: entry.specialityId,
        specialityText: entry.specialityText,
        year: entry.year,
        universityId: entry.universityId,
      ),
    );
    if (result is Ok) {
      await rememberWaitlist(ref, entry);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (result is Ok) {
        _view = _View.comingSoon;
      }
    });
    if (result case Err(:final failure)) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(onboardingOffersProvider);
    final me = ref.watch(meProvider);
    if (offers.hasError) {
      return ErrorView(
        failure: mapError(offers.error!),
        onRetry: () {
          ref.invalidate(onboardingOptionsProvider);
          ref.invalidate(meProvider);
        },
      );
    }
    if (!offers.hasValue || (!me.hasValue && !me.hasError)) {
      return const LoadingView();
    }
    final o = offers.requireValue;
    _prefill(o, me.hasValue ? me.requireValue : null);
    return switch (_view ?? _View.form) {
      _View.form => _form(context, o),
      _View.waitlist => _waitlist(context, o),
      _View.comingSoon => _ComingSoon(
        name: readWaitlist(ref.read(sharedPrefsProvider))?.name,
        onChange: () => setState(() => _view = _View.form),
        onSignOut: () => signOutEverywhere(ref),
      ),
    };
  }

  TextStyle? _title(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800);

  Widget _form(BuildContext context, OnboardingOffers offers) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final speciality = offers.speciality(_specialityId);
    final level = speciality?.level(_year);
    final label = TextStyle(color: kc.textSecondary);
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.md),
        Text(l10n.onboardingStudiesTitle, style: _title(context)),
        const SizedBox(height: KSpace.lg),
        DropdownButtonFormField<int>(
          initialValue: offers.universities.any((u) => u.id == _universityId)
              ? _universityId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.universityLabel,
            hintText: l10n.chooseUniversity,
          ),
          items: [
            for (final u in offers.universities)
              DropdownMenuItem<int>(
                value: u.id,
                child: Text(u.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _universityId = v),
        ),
        const SizedBox(height: KSpace.md),
        DropdownButtonFormField<int>(
          key: const ValueKey('speciality'),
          initialValue: speciality?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.studiesSpecialityLabel,
            hintText: l10n.studiesChooseSpeciality,
          ),
          items: [
            for (final s in offers.specialities)
              DropdownMenuItem<int>(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            final s = offers.speciality(v);
            if (s != null) {
              _choose(s);
            }
          }),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _view = _View.waitlist),
            child: Text(l10n.studiesNotListed),
          ),
        ),
        if (speciality != null) ...[
          const SizedBox(height: KSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.studyLevelYear, style: label),
          ),
          const SizedBox(height: KSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: KSpace.sm,
              runSpacing: KSpace.sm,
              children: [
                for (final lv in speciality.levels)
                  ChoiceChip(
                    key: ValueKey<String>('year-${lv.year}'),
                    label: Text(lv.labelIn(lang)),
                    selected: _year == lv.year,
                    onSelected: (_) => setState(() {
                      _year = lv.year;
                      _semester = lv.semesters.isEmpty
                          ? null
                          : lv.semesters.first;
                    }),
                  ),
              ],
            ),
          ),
        ],
        if (level != null && level.semesters.isNotEmpty) ...[
          const SizedBox(height: KSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.studyLevelSemester, style: label),
          ),
          const SizedBox(height: KSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: KSpace.sm,
              runSpacing: KSpace.sm,
              children: [
                for (final s in level.semesters)
                  ChoiceChip(
                    key: ValueKey<String>('semester-$s'),
                    label: Text(l10n.semesterLabel(s)),
                    selected: _semester == s,
                    onSelected: (_) => setState(() => _semester = s),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: KSpace.lg),
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
            if (_usernameError != null) {
              setState(() => _usernameError = null);
            }
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
        const SizedBox(height: KSpace.lg),
      ],
      action: FilledButton(
        onPressed: _busy ? null : () => _submit(offers),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.onboardingNext),
      ),
    );
  }

  Widget _waitlist(BuildContext context, OnboardingOffers offers) {
    final l10n = AppLocalizations.of(context);
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.md),
        Text(l10n.waitlistTitle, style: _title(context)),
        const SizedBox(height: KSpace.lg),
        if (offers.others.isNotEmpty)
          DropdownButtonFormField<int>(
            key: const ValueKey('other-speciality'),
            initialValue: _otherId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.studiesSpecialityLabel),
            items: [
              for (final o in offers.others)
                DropdownMenuItem<int>(
                  value: o.id,
                  child: Text(o.name, overflow: TextOverflow.ellipsis),
                ),
              DropdownMenuItem<int>(value: -1, child: Text(l10n.waitlistOther)),
            ],
            onChanged: (v) => setState(() => _otherId = v),
          ),
        if (offers.others.isEmpty || _otherId == -1) ...[
          const SizedBox(height: KSpace.md),
          TextField(
            controller: _otherName,
            decoration: InputDecoration(labelText: l10n.waitlistSpecialityText),
          ),
        ],
        const SizedBox(height: KSpace.md),
        TextField(
          controller: _otherYear,
          decoration: InputDecoration(labelText: l10n.waitlistYear),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _view = _View.form),
            child: Text(l10n.comingSoonChange),
          ),
        ),
      ],
      action: FilledButton(
        onPressed: _busy ? null : () => _joinWaitlist(offers),
        child: Text(l10n.waitlistJoin),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.name,
    required this.onChange,
    required this.onSignOut,
  });

  final String? name;
  final VoidCallback onChange;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final n = name;
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.xxl),
        Icon(Icons.hourglass_top_rounded, size: 72, color: kc.accentText),
        const SizedBox(height: KSpace.xl),
        Text(
          l10n.comingSoonTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KSpace.md),
        Text(
          n == null || n.isEmpty
              ? l10n.comingSoonBodyGeneric
              : l10n.comingSoonBody(n),
          textAlign: TextAlign.center,
          style: TextStyle(color: kc.textSecondary),
        ),
        const SizedBox(height: KSpace.lg),
        TextButton(onPressed: onChange, child: Text(l10n.comingSoonChange)),
      ],
      action: OutlinedButton(onPressed: onSignOut, child: Text(l10n.signOut)),
    );
  }
}
