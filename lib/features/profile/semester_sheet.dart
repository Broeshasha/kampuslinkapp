import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/profile/me_values.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';

/// Saves the semester on the server (set_semester) and refreshes get_me.
Future<Result<void>> saveSemester(
  WidgetRef ref,
  int semester,
  List<int> pinned,
) async {
  final api = ref.read(kampusApiProvider);
  if (api == null) return const Err(OfflineFailure());
  final r = await guard(() async {
    final me = await api.setSemester(semester, pinned);
    await storeServerStats(ref.read(sharedPrefsProvider), me);
  });
  ref.invalidate(serverStatsProvider);
  return r;
}

/// Contract 11, B1: "Which semester are you in?" + the semesters the
/// student still follows (debts, retakes).
Future<void> showSemesterSheet(BuildContext context, WidgetRef ref) async {
  final me = ref.read(serverStatsProvider).value;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<(int, List<int>)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SemesterSheet(
      current: currentSemesterOf(me),
      pinned: pinnedSemestersOf(me),
    ),
  );
  if (choice == null) return;
  final r = await saveSemester(ref, choice.$1, choice.$2);
  if (r case Err(:final failure)) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, failure))),
    );
  }
}

class _SemesterSheet extends StatefulWidget {
  const _SemesterSheet({required this.current, required this.pinned});

  final int? current;
  final List<int> pinned;

  @override
  State<_SemesterSheet> createState() => _SemesterSheetState();
}

class _SemesterSheetState extends State<_SemesterSheet> {
  late int? _current = widget.current;
  late final Set<int> _pinned = {...widget.pinned};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final current = _current;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.semesterPick,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KSpace.md),
          Wrap(
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              for (var s = 1; s <= 6; s++)
                ChoiceChip(
                  label: Text('S$s'),
                  selected: current == s,
                  onSelected: (_) => setState(() {
                    _current = s;
                    _pinned.remove(s);
                  }),
                ),
            ],
          ),
          const SizedBox(height: KSpace.lg),
          Text(
            l10n.semesterPinnedHelp,
            style: TextStyle(color: kc.textSecondary),
          ),
          const SizedBox(height: KSpace.sm),
          Wrap(
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              for (var s = 1; s <= 6; s++)
                if (s != current)
                  FilterChip(
                    label: Text('S$s'),
                    selected: _pinned.contains(s),
                    onSelected: (on) =>
                        setState(() => on ? _pinned.add(s) : _pinned.remove(s)),
                  ),
            ],
          ),
          const SizedBox(height: KSpace.lg),
          FilledButton(
            onPressed: current == null
                ? null
                : () =>
                      Navigator.of(context)
                          .pop((current, _pinned.toList()..sort())),
            child: Text(l10n.saveLabel),
          ),
        ],
      ),
    );
  }
}

/// Profile: the current semester, always visible; louder when a new
/// semester usually starts (Jan/Feb, Jun/Jul).
class SemesterCard extends ConsumerWidget {
  const SemesterCard({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final me = ref.watch(serverStatsProvider).value;
    final current = currentSemesterOf(me);
    final pinned = pinnedSemestersOf(me);
    final loud = semesterChangeMonths.contains((now ?? DateTime.now()).month);
    return Material(
      color: loud ? kc.accent.withValues(alpha: 0.10) : kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.card),
        side: BorderSide(color: loud ? kc.accent : kc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.event_note_rounded, color: kc.accentText),
        title: Text(
          current == null ? l10n.semesterNone : l10n.semesterCurrent(current),
        ),
        subtitle: loud || pinned.isNotEmpty
            ? Text(
                [
                  if (pinned.isNotEmpty)
                    l10n.semesterPinned(pinned.map((s) => 'S$s').join(', ')),
                  if (loud) l10n.semesterNewHint,
                ].join('\n'),
              )
            : null,
        trailing: const Icon(Icons.edit_rounded),
        onTap: () => showSemesterSheet(context, ref),
      ),
    );
  }
}

/// Modules tab, only in the semester-change months, until dismissed for
/// that month.
class SemesterBanner extends ConsumerStatefulWidget {
  const SemesterBanner({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<SemesterBanner> createState() => _SemesterBannerState();
}

class _SemesterBannerState extends ConsumerState<SemesterBanner> {
  bool _hidden = false;

  String get _key {
    final d = widget.now ?? DateTime.now();
    return 'semester_banner_${d.year}_${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final prefs = ref.watch(sharedPrefsProvider);
    if (_hidden ||
        !semesterChangeMonths.contains(now.month) ||
        (prefs.getBool(_key) ?? false)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final current = currentSemesterOf(ref.watch(serverStatsProvider).value);
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Material(
        color: kc.accent.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.chip),
          side: BorderSide(color: kc.accent.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                current == null
                    ? l10n.semesterNone
                    : l10n.semesterCurrent(current),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                l10n.semesterNewHint,
                style: TextStyle(color: kc.textSecondary),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      prefs.setBool(_key, true);
                      setState(() => _hidden = true);
                    },
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => showSemesterSheet(context, ref),
                    child: Text(l10n.semesterUpdate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
