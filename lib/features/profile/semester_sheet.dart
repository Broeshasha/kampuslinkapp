import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart';
import '../../data/profile/study_level.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';

/// "My year & semester" sheet: the year chips and the semesters of that
/// year come from catalog.levels (no list in the app); Save ->
/// set_study_level, queued when offline (lead WP17/18-2).
Future<void> showStudyLevelSheet(BuildContext context, WidgetRef ref) async {
  final level = ref.read(studyLevelProvider);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final levels = ref.read(catalogValueProvider)?.levels ?? const [];
  if (levels.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorOffline)));
    unawaited(ref.read(catalogProvider.notifier).refresh());
    return;
  }
  final choice = await showModalBottomSheet<(String, int?)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StudyLevelSheet(
      levels: levels,
      year: level.year,
      semester: level.semester,
    ),
  );
  if (choice == null) return;
  final r = await ref
      .read(studyLevelProvider.notifier)
      .save(choice.$1, choice.$2);
  final pending = ref.read(studyLevelProvider).pending;
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (r) {
        Err(:final failure) => failureMessage(l10n, failure),
        Ok() when pending => l10n.studyLevelPending,
        Ok() => l10n.studyLevelSaved,
      }),
    ),
  );
}

class _StudyLevelSheet extends StatefulWidget {
  const _StudyLevelSheet({required this.levels, this.year, this.semester});

  final List<CatalogLevel> levels;
  final String? year;
  final int? semester;

  @override
  State<_StudyLevelSheet> createState() => _StudyLevelSheetState();
}

class _StudyLevelSheetState extends State<_StudyLevelSheet> {
  late CatalogLevel _level = widget.levels.firstWhere(
    (l) => l.year == widget.year,
    orElse: () => widget.levels.first,
  );
  late int? _semester = _pick(widget.semester);

  int? _pick(int? wanted) {
    final list = _level.semesters;
    if (list.isEmpty) return null;
    return list.contains(wanted) ? wanted : list.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final label = TextStyle(color: kc.textSecondary);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.studyLevelTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KSpace.lg),
          Text(l10n.studyLevelYear, style: label),
          const SizedBox(height: KSpace.sm),
          Wrap(
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              for (final lv in widget.levels)
                ChoiceChip(
                  key: ValueKey<String>('year-${lv.year}'),
                  label: Text(lv.labelIn(lang)),
                  selected: _level.year == lv.year,
                  onSelected: (_) => setState(() {
                    _level = lv;
                    _semester = _pick(_semester);
                  }),
                ),
            ],
          ),
          if (_level.semesters.isNotEmpty) ...[
            const SizedBox(height: KSpace.lg),
            Text(l10n.studyLevelSemester, style: label),
            const SizedBox(height: KSpace.sm),
            Wrap(
              spacing: KSpace.sm,
              runSpacing: KSpace.sm,
              children: [
                for (final s in _level.semesters)
                  ChoiceChip(
                    key: ValueKey<String>('semester-$s'),
                    label: Text(l10n.semesterLabel(s)),
                    selected: _semester == s,
                    onSelected: (_) => setState(() => _semester = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: KSpace.xl),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop((_level.year, _semester)),
            child: Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}

/// "L2, Semester 3" (year label from the catalog in the UI language).
String studyLevelText(
  AppLocalizations l10n,
  Catalog? catalog,
  StudyLevel level,
  String lang,
) {
  final year = level.year;
  if (year == null || year.isEmpty) return l10n.semesterNone;
  final label = catalog?.level(year)?.labelIn(lang) ?? year;
  final semester = level.semester;
  return semester == null ? label : l10n.studyLevelValue(label, semester);
}

/// Profile: "My year & semester  L2, Semester 3  Change", always there.
class SemesterCard extends ConsumerWidget {
  const SemesterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final level = ref.watch(studyLevelProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final value = studyLevelText(
      l10n,
      ref.watch(catalogValueProvider),
      level,
      lang,
    );
    final unset = level.year == null || level.year!.isEmpty;
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.card),
        side: BorderSide(color: unset ? kc.accent : kc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.event_note_rounded, color: kc.accentText),
        title: Text(l10n.studyLevelTitle),
        subtitle: Text(
          level.pending ? '$value\n${l10n.studyLevelPending}' : value,
        ),
        trailing: TextButton(
          onPressed: () => showStudyLevelSheet(context, ref),
          child: Text(l10n.studyLevelChange),
        ),
        onTap: () => showStudyLevelSheet(context, ref),
      ),
    );
  }
}

const _bannerKey = 'semester_banner_hidden_until';

/// Top of Home inside config.semester_banner_windows; "x" snoozes it for
/// config.semester_banner_snooze_days.
class SemesterBanner extends ConsumerStatefulWidget {
  const SemesterBanner({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<SemesterBanner> createState() => _SemesterBannerState();
}

class _SemesterBannerState extends ConsumerState<SemesterBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final prefs = ref.watch(sharedPrefsProvider);
    final config = ref.watch(catalogValueProvider)?.config ?? const {};
    final windows = config['semester_banner_windows'];
    final snooze = config['semester_banner_snooze_days'];
    final until = DateTime.tryParse(prefs.getString(_bannerKey) ?? '');
    if (_hidden ||
        !semesterBannerDue(
          now,
          windows is List ? windows : const [],
          hiddenUntil: until,
        )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.md, 0, KSpace.md, KSpace.xs),
      child: MaxWidth(
        child: SemesterBannerCard(
          onChange: () => showStudyLevelSheet(context, ref),
          onDismiss: () {
            prefs.setString(
              _bannerKey,
              now
                  .add(Duration(days: snooze is num ? snooze.toInt() : 14))
                  .toIso8601String(),
            );
            setState(() => _hidden = true);
          },
        ),
      ),
    );
  }
}

/// The banner itself (no state), also used by the golden test.
class SemesterBannerCard extends StatelessWidget {
  const SemesterBannerCard({
    super.key,
    required this.onChange,
    required this.onDismiss,
  });

  final VoidCallback onChange;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Material(
      color: kc.accent.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: kc.accent.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChange,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpace.md,
            KSpace.xs,
            KSpace.xs,
            KSpace.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.event_repeat_rounded, color: kc.accentText, size: 20),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Text(
                  l10n.semesterBannerText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, color: kc.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
