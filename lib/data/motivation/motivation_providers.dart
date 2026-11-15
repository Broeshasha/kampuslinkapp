import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/catalog.dart';
import '../profile/study_level.dart';
import '../providers.dart';
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
  return ref
      .read(motivationStoreProvider)
      .today([for (final m in modules) m.id], weekGoal: ref.watch(weekGoalProvider));
});

final myWhyProvider = FutureProvider<MyWhy>(
  (ref) => ref.watch(motivationStoreProvider).why(),
);
