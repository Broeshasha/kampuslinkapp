import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../lessons/lesson_repository.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import '../sync/sync_controller.dart';
import 'feed_repository.dart';
import 'quiz_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
  ),
);

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(progressRepositoryProvider),
  ),
);

/// Changes only when a module's downloaded content changes (not on every
/// sync), so the feed does not reshuffle under the student's finger.
final downloadedKeyProvider = Provider<String>(
  (ref) => switch (ref.watch(visibleModulesProvider)) {
    AsyncData(:final value) => [
      for (final m in value)
        if (m.localVersion > 0) '${m.id}:${m.localVersion}',
    ].join(','),
    _ => '',
  },
);

class FeedAhead extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool ahead}) => state = ahead;
}

/// false = due + new cards; true = "practise ahead" (not due yet).
final feedAheadProvider = NotifierProvider<FeedAhead, bool>(FeedAhead.new);

/// The feed is loaded once (and again when downloads change or on
/// "check again"); answering a card never reorders the open list.
final feedProvider = FutureProvider<List<FeedCard>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const <FeedCard>[];
  ref.watch(downloadedKeyProvider);
  return ref
      .watch(feedRepositoryProvider)
      .feed(ahead: ref.watch(feedAheadProvider));
});

final nextDueProvider = FutureProvider<DateTime?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  ref.watch(feedProvider);
  return ref.watch(feedRepositoryProvider).nextDueAt();
});

final studyDaysProvider = StreamProvider<Map<String, int>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const {});
  return ref.watch(feedRepositoryProvider).watchStudyDays();
});

/// Unfinished lessons of the CURRENT semester only (WP17-A, A3).
final continueProvider = StreamProvider<List<ContinueItem>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const []);
  final semester = ref.watch(currentSemesterProvider);
  return ref
      .watch(feedRepositoryProvider)
      .watchContinue()
      .map(
        (items) => [
          for (final i in items)
            if (inSemester(i.module, semester)) i,
        ],
      );
});

const _statsKey = 'server_stats';

const _statsKeys = [
  'xp',
  'current_streak',
  'longest_streak',
  'study_goal_minutes',
  'username',
  'university_name',
  'speciality_name',
  'academic_year',
  'reminders_enabled',
  // Contract 11 / WP17-A
  'current_semester',
  'is_admin',
];

/// Keeps the parts of get_me() the app shows (cached for offline starts).
Future<Map<String, dynamic>> storeServerStats(
  SharedPreferences prefs,
  Map<String, dynamic> me,
) async {
  final stats = <String, dynamic>{for (final key in _statsKeys) key: me[key]};
  await prefs.setString(_statsKey, jsonEncode(stats));
  return stats;
}

/// Server stats (get_me: xp, current_streak, study_goal_minutes), refreshed
/// after every successful sync and cached for offline starts. null = never
/// fetched: the Home header then falls back to the local streak.
final serverStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  ref.watch(syncControllerProvider.select((s) => s.lastSyncedAt));
  final prefs = ref.read(sharedPrefsProvider);
  Map<String, dynamic>? cached() {
    final raw = prefs.getString(_statsKey);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? v.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }

  final api = ref.watch(kampusApiProvider);
  if (api == null) return cached();
  try {
    final me = await api.getMe();
    if (me == null) return cached();
    return await storeServerStats(prefs, me);
  } catch (error) {
    appLog.info('stats offline: $error');
    return cached();
  }
});

final savedCardsProvider = StreamProvider<List<FeedCard>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const []);
  return ref.watch(feedRepositoryProvider).watchSaved();
});

final lessonsDoneProvider = StreamProvider<int>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(0);
  return ref.watch(feedRepositoryProvider).watchLessonsDone();
});
