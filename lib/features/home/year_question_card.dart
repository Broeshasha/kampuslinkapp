import 'dart:async';

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
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';

/// Contract 11, B2: "Did you pass?" on Home while get_me says it is due
/// (from 1 July until answered). The answer moves the academic year on the
/// server; the module list then changes, so a full sync follows.
class YearQuestionCard extends ConsumerStatefulWidget {
  const YearQuestionCard({super.key});

  @override
  ConsumerState<YearQuestionCard> createState() => _YearQuestionCardState();
}

class _YearQuestionCardState extends ConsumerState<YearQuestionCard> {
  bool _busy = false;

  Future<void> _answer(String result) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(kampusApiProvider);
    setState(() => _busy = true);
    final Result<void> r = api == null
        ? const Err(OfflineFailure())
        : await guard(() async {
            final me = await api.confirmYear(result);
            await storeServerStats(ref.read(sharedPrefsProvider), me);
          });
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case Ok():
        ref.invalidate(serverStatsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.yearThanks)));
        unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      case Err(:final failure):
        messenger.showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, failure))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(serverStatsProvider).value;
    if (!yearQuestionDue(me)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.sm),
      child: MaxWidth(
        child: Material(
          color: kc.xp.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.chip),
            side: BorderSide(color: kc.xp.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.yearQuestionTitle(yearQuestionKey(me)),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: KSpace.sm),
                if (_busy)
                  const LinearProgressIndicator()
                else
                  Wrap(
                    spacing: KSpace.sm,
                    runSpacing: KSpace.xs,
                    children: [
                      FilledButton(
                        onPressed: () => _answer('passed'),
                        child: Text(l10n.yearPassed),
                      ),
                      OutlinedButton(
                        onPressed: () => _answer('passed_with_debts'),
                        child: Text(l10n.yearPassedDebts),
                      ),
                      OutlinedButton(
                        onPressed: () => _answer('repeat'),
                        child: Text(l10n.yearRepeat),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
