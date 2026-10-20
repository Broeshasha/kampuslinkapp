import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../lessons/lesson_repository.dart';
import '../providers.dart';
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
  (ref) => switch (ref.watch(modulesStreamProvider)) {
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

final continueProvider = StreamProvider<List<ContinueItem>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const []);
  return ref.watch(feedRepositoryProvider).watchContinue();
});
