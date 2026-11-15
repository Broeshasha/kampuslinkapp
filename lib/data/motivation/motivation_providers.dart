import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity.dart';
import '../../core/errors/result.dart';
import '../catalog/catalog.dart';
import '../learning/feed_repository.dart' show dayKey;
import '../profile/study_level.dart';
import '../providers.dart';
import '../shop/shop_providers.dart';
import 'bac_readiness.dart';
import 'motivation_store.dart';

final motivationStoreProvider = Provider<MotivationStore>(
  (ref) => MotivationStore(ref.watch(appDatabaseProvider)),
);

/// Days per week for the weekly goal (app_config week_goal_days, default 5).
final weekGoalProvider = Provider<int>((ref) {
  final v = ref.watch(catalogValueProvider)?.config['week_goal_days'];
  final n = v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 5;
  return n.clamp(1, 7);
});

/// Today's Mission. Recomputed after every study action: each one queues an
/// op, so the pending-op count changes (no extra wiring in the screens).
final missionProvider = FutureProvider<MissionStatus?>((ref) async {
  ref.watch(pendingOpsProvider);
  final modules = ref.watch(visibleModulesProvider).value;
  if (modules == null) return null;
  final wallet = ref.watch(walletControllerProvider);
  final goal = ref.watch(weekGoalProvider);
  final status = await ref
      .read(motivationStoreProvider)
      .today(
        [for (final m in modules) m.id],
        weekGoal: goal,
        frozenWeeks: wallet?.frozenWeeks ?? const {},
      );
  _autoWeekFreeze(ref, status);
  return status;
});

final _freezeTried = <String>{};

/// MOT-2: last week missed the goal, there was a run to protect and a week
/// freeze is held -> the server spends it (once per week, never twice).
void _autoWeekFreeze(Ref ref, MissionStatus m) {
  final wallet = ref.read(walletControllerProvider);
  if (wallet == null || wallet.weekFreezes <= 0) return;
  final last = m.weekStart.subtract(const Duration(days: 7));
  final monday = dayKey(last);
  if (m.lastWeekDays >= m.weekGoal || wallet.frozenWeeks.contains(monday)) return;
  // A run worth keeping: the week before last reached the goal (or was frozen).
  final runBefore = weeksInRow(
    m.missionDays,
    last,
    m.weekGoal,
    frozen: wallet.frozenWeeks,
  );
  if (runBefore == 0 || !_freezeTried.add(monday)) return;
  final api = ref.read(kampusApiProvider);
  if (api == null || !ref.read(isOnlineProvider)) {
    _freezeTried.remove(monday);
    return;
  }
  unawaited(() async {
    final r = await guard(() => api.useWeekFreeze(monday));
    if (r is Ok) await ref.read(walletControllerProvider.notifier).refresh();
  }());
}

/// MOT-2: bac countdown (null = not bac / no date / passed).
final bacCountdownProvider = Provider<({int value, bool days})?>((ref) {
  if (!ref.watch(isBacProvider)) return null;
  final config = ref.watch(catalogValueProvider)?.config ?? const {};
  return bacCountdown(config['bac_date'], config['bac_date_confirmed'], DateTime.now());
});

/// MOT-2: readiness bars of the bac subjects the student sees.
final bacReadinessProvider = FutureProvider<List<SubjectReadiness>>((ref) async {
  ref.watch(pendingOpsProvider);
  if (!ref.watch(isBacProvider)) return const [];
  final modules = ref.watch(visibleModulesProvider).value ?? const [];
  final subjects = BacSubject.listFrom(
    ref.watch(catalogValueProvider)?.config['bac_subjects'],
    {for (final m in modules) m.id},
  );
  return bacReadiness(ref.read(appDatabaseProvider), subjects);
});

final myWhyProvider = FutureProvider<MyWhy>(
  (ref) => ref.watch(motivationStoreProvider).why(),
);
