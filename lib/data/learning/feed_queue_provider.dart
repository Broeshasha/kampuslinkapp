import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/result.dart';
import '../cases/case_repository.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import 'feed_pool.dart';
import 'feed_queue.dart';
import 'feed_seen.dart';
import 'learning_providers.dart';

final feedPoolLoaderProvider = Provider<FeedPoolLoader>(
  (ref) => FeedPoolLoader(
    ref.watch(appDatabaseProvider),
    ref.watch(feedRepositoryProvider),
    ref.watch(caseRepositoryProvider),
  ),
);

final feedSeenStoreProvider = Provider<FeedSeenStore>(
  (ref) => FeedSeenStore(ref.watch(appDatabaseProvider)),
);

/// The Home feed queue (lead brief 2, C). Built once per session and
/// never reordered under the finger: it only grows at the end (endless)
/// and is rebuilt on "shuffle", "practise ahead", or when new content
/// arrives while it is empty.
class FeedQueueController extends AsyncNotifier<List<FeedItem>> {
  Map<FeedBucket, List<FeedItem>> _pool = const {};
  Map<String, SeenInfo> _seen = {};
  math.Random _random = math.Random();

  @override
  Future<List<FeedItem>> build() async {
    if (!ref.watch(isSignedInProvider)) return const [];
    final ahead = ref.watch(feedAheadProvider);
    // A new semester rebuilds the whole queue at once (WP17-A).
    ref.watch(currentSemesterProvider);
    ref.listen<String>(downloadedKeyProvider, (previous, next) {
      if (previous != next && (state.value?.isEmpty ?? false)) {
        ref.invalidateSelf();
      }
    });
    return _fresh(ahead: ahead);
  }

  Future<List<FeedItem>> _fresh({required bool ahead}) async {
    final now = DateTime.now();
    final store = ref.read(feedSeenStoreProvider);
    final progress = await ref.read(caseRepositoryProvider).all();
    _seen = await store.load();
    _pool = await ref
        .read(feedPoolLoaderProvider)
        .load(
          now: now,
          ahead: ahead,
          finishedSets: {
            for (final e in progress.entries)
              if (e.value.finished) e.key: true,
          },
          startedSets: {
            for (final e in progress.entries)
              if (e.value.started && !e.value.finished) e.key,
          },
          semester: ref.read(currentSemesterProvider),
        );
    _random = math.Random(now.microsecondsSinceEpoch);
    final list = buildFeedQueue(
      pool: _pool,
      random: _random,
      now: now,
      seen: _seen,
      lastFirst: await store.lastFirst(),
    );
    if (list.isNotEmpty) {
      await store.setLastFirst(list.first.key);
      _seen = markShown(_seen, list.first.key, now);
      unawaited(guard(() => store.save(_seen)));
    }
    return list;
  }

  /// "Shuffle": a new queue, starting from the top.
  Future<void> shuffle() async {
    final ahead = ref.read(feedAheadProvider);
    state = await AsyncValue.guard(() => _fresh(ahead: ahead));
  }

  /// The post at [index] is on screen: remember it, and add a batch when
  /// fewer than 15 posts are left.
  void shown(int index) {
    final list = state.value;
    if (list == null || index < 0 || index >= list.length) return;
    final now = DateTime.now();
    _seen = markShown(_seen, list[index].key, now);
    unawaited(guard(() => ref.read(feedSeenStoreProvider).save(_seen)));
    if (index >= list.length - 15) {
      final more = buildFeedQueue(
        pool: _pool,
        random: _random,
        now: now,
        seen: _seen,
        before: list,
      );
      if (more.isNotEmpty) state = AsyncData([...list, ...more]);
    }
  }

  /// How the student did on a post ('right' / 'wrong').
  void outcome(String key, String result) {
    _seen = markOutcome(_seen, key, result, DateTime.now());
    unawaited(guard(() => ref.read(feedSeenStoreProvider).save(_seen)));
  }
}

final feedQueueProvider =
    AsyncNotifierProvider<FeedQueueController, List<FeedItem>>(
      FeedQueueController.new,
    );
