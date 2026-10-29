import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/profile/offers.dart';
import '../../data/profile/study_level.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../onboarding/onboarding_status.dart';

/// Profile row: opens Profile > My studies.
class StudyProfileTile extends StatelessWidget {
  const StudyProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.school_outlined),
      title: Text(l10n.myStudiesTitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/profile/studies'),
    );
  }
}

/// Profile > My studies: speciality + year + semester, only what is
/// offered (set_study_profile). Then: catalog, feed and the new modules
/// download in the background (current-semester rule).
class StudyProfilePage extends ConsumerStatefulWidget {
  const StudyProfilePage({super.key});

  @override
  ConsumerState<StudyProfilePage> createState() => _StudyProfilePageState();
}

class _StudyProfilePageState extends ConsumerState<StudyProfilePage> {
  int? _specialityId;
  String? _year;
  int? _semester;
  bool _ready = false;
  bool _busy = false;

  void _start(OnboardingOffers offers) {
    if (_ready) {
      return;
    }
    _ready = true;
    final level = ref.read(studyLevelProvider);
    final me = ref.read(meProvider);
    final mine = me.hasValue ? (me.requireValue?['speciality_id']) : null;
    final s =
        offers.speciality(mine is num ? mine.toInt() : null) ??
        (offers.specialities.isNotEmpty ? offers.specialities.first : null);
    if (s == null) {
      return;
    }
    _specialityId = s.id;
    final lv =
        s.level(level.year) ?? (s.levels.isEmpty ? null : s.levels.first);
    _year = lv?.year;
    _semester = lv == null || lv.semesters.isEmpty
        ? null
        : (lv.semesters.contains(level.semester)
              ? level.semester
              : lv.semesters.first);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final specialityId = _specialityId;
    final year = _year;
    final api = ref.read(studiesApiProvider);
    if (specialityId == null || year == null) {
      return;
    }
    if (api == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.myStudiesOffline)));
      return;
    }
    setState(() => _busy = true);
    final result = await guard(
      () => api.setStudyProfile(
        specialityId: specialityId,
        year: year,
        semester: _semester,
      ),
    );
    if (result case Ok(:final value)) {
      if (value.isNotEmpty) {
        await storeServerStats(ref.read(sharedPrefsProvider), value);
      }
      ref.invalidate(meProvider);
      ref.invalidate(serverStatsProvider);
      await ref.read(catalogProvider.notifier).refresh();
      // Local level + feed rebuild + background sync (downloads).
      await ref.read(studyLevelProvider.notifier).save(year, _semester);
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        messenger.showSnackBar(SnackBar(content: Text(l10n.myStudiesSaved)));
        unawaited(navigator.maybePop());
      case Err(:final failure):
        final notOffered =
            failure is ValidationFailure &&
            const {
              'not_offered',
              'invalid_year',
              'invalid_semester',
            }.contains(failure.code);
        if (notOffered) {
          ref.invalidate(onboardingOptionsProvider);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              notOffered
                  ? l10n.studiesNotOffered
                  : failureMessage(l10n, failure),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final offers = ref.watch(onboardingOffersProvider);
    final Widget body;
    if (offers.hasError) {
      final failure = mapError(offers.error!);
      body = failure is OfflineFailure
          ? EmptyView(
              icon: Icons.cloud_off_rounded,
              title: l10n.myStudiesOffline,
            )
          : ErrorView(
              failure: failure,
              onRetry: () => ref.invalidate(onboardingOptionsProvider),
            );
    } else if (!offers.hasValue) {
      body = const LoadingView();
    } else {
      final o = offers.requireValue;
      _start(o);
      final speciality = o.speciality(_specialityId);
      final level = speciality?.level(_year);
      final label = TextStyle(color: kc.textSecondary);
      body = ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: speciality?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.studiesSpecialityLabel,
                  ),
                  items: [
                    for (final s in o.specialities)
                      DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    final s = o.speciality(v);
                    if (s == null) {
                      return;
                    }
                    _specialityId = s.id;
                    final lv = s.levels.isEmpty ? null : s.levels.first;
                    _year = lv?.year;
                    _semester = lv == null || lv.semesters.isEmpty
                        ? null
                        : lv.semesters.first;
                  }),
                ),
                if (speciality != null) ...[
                  const SizedBox(height: KSpace.lg),
                  Text(l10n.studyLevelYear, style: label),
                  const SizedBox(height: KSpace.sm),
                  Wrap(
                    spacing: KSpace.sm,
                    runSpacing: KSpace.sm,
                    children: [
                      for (final lv in speciality.levels)
                        ChoiceChip(
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
                ],
                if (level != null && level.semesters.isNotEmpty) ...[
                  const SizedBox(height: KSpace.lg),
                  Text(l10n.studyLevelSemester, style: label),
                  const SizedBox(height: KSpace.sm),
                  Wrap(
                    spacing: KSpace.sm,
                    runSpacing: KSpace.sm,
                    children: [
                      for (final s in level.semesters)
                        ChoiceChip(
                          label: Text(l10n.semesterLabel(s)),
                          selected: _semester == s,
                          onSelected: (_) => setState(() => _semester = s),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: KSpace.xl),
                FilledButton(
                  onPressed: _busy || _year == null ? null : _save,
                  child: Text(l10n.saveLabel),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myStudiesTitle)),
      body: body,
    );
  }
}
