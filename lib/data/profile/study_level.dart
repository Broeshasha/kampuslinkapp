import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../catalog/catalog.dart';
import '../db/app_database.dart';
import '../learning/feed_queue_provider.dart';
import '../learning/learning_providers.dart';
import '../providers.dart';
import '../sync/sync_controller.dart';

/// The year the student is in and the semester he studies now (null for a
/// year without semesters). Allowed values come from catalog.levels.
class StudyLevel {
  const StudyLevel({this.year, this.semester, this.pending = false});

  final String? year;
  final int? semester;

  /// Chosen offline, not on the server yet.
  final bool pending;
}

/// Hard rule (lead WP17/18-3): a module is shown when its semester is the
/// current one, or when it has no semester (a whole-year module). With no
/// current semester (a year without semesters), every module of the year.
bool inSemester(ModuleRow? module, int? semester) =>
    module != null &&
    (semester == null ||
        module.semester == null ||
        module.semester == semester);

List<ModuleRow> visibleModules(List<ModuleRow> all, int? semester) => [
  for (final m in all)
    if (inSemester(m, semester)) m,
];

int? _monthDay(Object? v) {
  final m = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch('${v ?? ''}'.trim());
  if (m == null) return null;
  return int.parse(m.group(1)!) * 100 + int.parse(m.group(2)!);
}

/// The "Finished your semester?" banner: inside one of
/// config.semester_banner_windows [{from: "MM-DD", to: "MM-DD"}] (a window
/// may wrap over the new year), unless snoozed until [hiddenUntil].
bool semesterBannerDue(
  DateTime now,
  List<Object?> windows, {
  DateTime? hiddenUntil,
}) {
  if (hiddenUntil != null && now.isBefore(hiddenUntil)) return false;
  final d = now.month * 100 + now.day;
  for (final w in windows) {
    if (w is! Map) continue;
    final from = _monthDay(w['from']);
    final to = _monthDay(w['to']);
    if (from == null || to == null) continue;
    final inside = from <= to ? d >= from && d <= to : d >= from || d <= to;
    if (inside) return true;
  }
  return false;
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
  Future<Result<void>> save(String year, int? semester) async {
    final prefs = ref.read(sharedPrefsProvider);
    final before = state;
    await prefs.setString(
      _pendingKey,
      jsonEncode({'year': year, 'semester': semester}),
    );
    state = StudyLevel(year: year, semester: semester, pending: true);
    final changed = before.semester != semester || before.year != year;
    if (changed) {
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
    if (changed) {
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
    if (pending == null || year == null || year.isEmpty) {
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
      unawaited(ref.read(catalogProvider.notifier).refresh());
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
  final catalog = ref.watch(catalogValueProvider);
  return ref.watch(modulesStreamProvider).whenData((all) {
    final list = visibleModules(all, semester);
    // Catalog order (the server decides), unknown modules last.
    if (catalog != null) {
      list.sort(
        (a, b) => catalog.orderOf(a.id).compareTo(catalog.orderOf(b.id)),
      );
    }
    return list;
  });
});

/// Ids of the visible modules (empty while loading: nothing leaks).
final visibleModuleIdsProvider = Provider<Set<int>>(
  (ref) => switch (ref.watch(visibleModulesProvider)) {
    AsyncData(:final value) => {for (final m in value) m.id},
    _ => const <int>{},
  },
);
