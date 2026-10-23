import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../db/app_database.dart';
import '../learning/feed_queue_provider.dart';
import '../learning/learning_providers.dart';
import '../providers.dart';
import '../sync/sync_controller.dart';

/// LMD: the 2 semesters of each year (lead WP17-A).
const yearSemesters = <String, List<int>>{
  'L1': [1, 2],
  'L2': [3, 4],
  'L3': [5, 6],
  'M1': [1, 2],
  'M2': [3, 4],
};

/// The year the student is in and the semester he studies now. The
/// semester decides EVERYTHING the app shows (lead WP17-A, A3).
class StudyLevel {
  const StudyLevel({this.year, this.semester, this.pending = false});

  final String? year;
  final int? semester;

  /// Chosen offline, not on the server yet.
  final bool pending;
}

/// A3 hard rule: a module is shown only when its semester is the current
/// one. Without a current semester (never chosen): every module that has a
/// semester. A module without a semester is never shown.
bool inSemester(ModuleRow? module, int? semester) =>
    module != null &&
    module.semester != null &&
    (semester == null || module.semester == semester);

List<ModuleRow> visibleModules(List<ModuleRow> all, int? semester) => [
  for (final m in all)
    if (inSemester(m, semester)) m,
];

/// A2: the "Finished your semester?" banner shows from Jan 15 to Mar 15 and
/// from Jun 15 to Oct 15 (inclusive), unless dismissed in the last 14 days.
bool semesterBannerDue(DateTime now, {DateTime? hiddenUntil}) {
  if (hiddenUntil != null && now.isBefore(hiddenUntil)) return false;
  final d = now.month * 100 + now.day;
  return (d >= 115 && d <= 315) || (d >= 615 && d <= 1015);
}

const _pendingKey = 'study_level_pending';

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

class StudyLevelController extends Notifier<StudyLevel> {
  @override
  StudyLevel build() {
    // Retry a level chosen offline after every successful sync.
    ref.listen(syncControllerProvider.select((s) => s.lastSyncedAt), (
      previous,
      next,
    ) {
      if (next != null && previous != next) unawaited(flushPending());
    });
    final pending = _readPending();
    if (pending != null) return pending;
    final me = ref.watch(serverStatsProvider).value;
    final year = me?['academic_year'];
    return StudyLevel(
      year: year == null || '$year'.isEmpty ? null : '$year',
      semester: _int(me?['current_semester']),
    );
  }

  StudyLevel? _readPending() {
    final raw = ref.read(sharedPrefsProvider).getString(_pendingKey);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      if (v is! Map) return null;
      return StudyLevel(
        year: '${v['year'] ?? ''}',
        semester: _int(v['semester']),
        pending: true,
      );
    } on FormatException {
      return null;
    }
  }

  /// Saves year + semester: applied on the phone at once (the feed, the
  /// Modules tab and the downloads switch now), sent to the server now or
  /// after the next sync when offline. A refused value (invalid_year...)
  /// is rolled back and returned as the failure.
  Future<Result<void>> save(String year, int semester) async {
    final prefs = ref.read(sharedPrefsProvider);
    final before = state;
    await prefs.setString(
      _pendingKey,
      jsonEncode({'year': year, 'semester': semester}),
    );
    state = StudyLevel(year: year, semester: semester, pending: true);
    if (before.semester != semester) {
      await guard(() => ref.read(feedSeenStoreProvider).setLastFirst(''));
      ref.invalidate(feedQueueProvider);
    }
    final r = await flushPending();
    if (r case Err(:final failure) when failure is! OfflineFailure) {
      await prefs.remove(_pendingKey);
      state = before;
      ref.invalidate(feedQueueProvider);
      return r;
    }
    if (before.semester != semester) {
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    }
    return const Ok(null);
  }

  /// Sends a level chosen offline; Ok when there is nothing to send.
  Future<Result<void>> flushPending() async {
    final prefs = ref.read(sharedPrefsProvider);
    final pending = _readPending();
    final year = pending?.year;
    final semester = pending?.semester;
    if (pending == null || year == null || semester == null) {
      return const Ok(null);
    }
    final api = ref.read(kampusApiProvider);
    if (api == null) return const Err(OfflineFailure());
    final r = await guard(() async {
      final me = await api.setStudyLevel(year, semester);
      await storeServerStats(prefs, me);
    });
    if (r is Ok) {
      await prefs.remove(_pendingKey);
      ref.invalidate(serverStatsProvider);
      appLog.info('study level saved: $year S$semester');
    }
    return r;
  }
}

final studyLevelProvider = NotifierProvider<StudyLevelController, StudyLevel>(
  StudyLevelController.new,
);

final currentSemesterProvider = Provider<int?>(
  (ref) => ref.watch(studyLevelProvider.select((l) => l.semester)),
);

/// The Modules tab, the downloads and everything built from modules use
/// THIS list, never the raw one.
final visibleModulesProvider = Provider<AsyncValue<List<ModuleRow>>>((ref) {
  final semester = ref.watch(currentSemesterProvider);
  return ref
      .watch(modulesStreamProvider)
      .whenData((all) => visibleModules(all, semester));
});

/// Ids of the visible modules (empty while loading: nothing leaks).
final visibleModuleIdsProvider = Provider<Set<int>>(
  (ref) => switch (ref.watch(visibleModulesProvider)) {
    AsyncData(:final value) => {for (final m in value) m.id},
    _ => const <int>{},
  },
);
