import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/result.dart';
import '../../core/logging/logger.dart';
import '../../core/logging/startup_trace.dart';
import '../cases/case_repository.dart';
import '../catalog/catalog.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import 'feed_pool.dart';
import 'feed_queue.dart';
import 'feed_seen.dart';
import 'feed_snapshot.dart';
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

final feedSnapshotStoreProvider = Provider<FeedSnapshotStore>(
  (ref) => FeedSnapshotStore(
    ref.watch(appDatabaseProvider),
    ref.watch(caseRepositoryProvider),
  ),
);

/// The Home feed queue (lead brief 2, C). Never reordered under the
/// finger: it only grows at the end (endless) and is rebuilt on "shuffle",
/// "practise ahead", or when new content arrives while it is empty.
///
/// Fast start: the posts saved at the end of the last session (snapshot)
/// are shown at once; the full pool is built afterwards, in the background,
/// for the next batches.
class FeedQueueController extends AsyncNotifier<List<FeedItem>> {
  Map<FeedBucket, List<FeedItem>> _pool = const {};
  Map<String, SeenInfo> _seen = {};
  math.Random _random = math.Random();
  int _index = 0;

  /// Start-up trace: how many times the queue was built (a rebuild during
  /// start-up costs a full pool build).
  static int _builds = 0;

  @override
  Future<List<FeedItem>> build() async {
    if (!ref.watch(isSignedInProvider)) {
      return const [];
    }
    final build = ++_builds;
    startupTrace.mark('feed build #$build');
    final ahead = ref.watch(feedAheadProvider);
    // A new semester rebuilds the whole queue at once (WP17-A).
    final semester = ref.watch(currentSemesterProvider);
    ref.listen<String>(downloadedKeyProvider, (previous, next) {
      if (previous != next && (state.value?.isEmpty ?? false)) {
        ref.invalidateSelf();
      }
    });
    _index = 0;
    _pool = const {};
    if (!ahead) {
      final restored = await _restore(semester);
      startupTrace.mark('feed snapshot #$build', '${restored.length} posts');
      if (restored.isNotEmpty) {
        unawaited(_warmPool(ahead: ahead, first: restored.first.key));
        return restored;
      }
    }
    final fresh = await _fresh(ahead: ahead);
    startupTrace.mark('feed full build #$build', '${fresh.length} posts');
    return fresh;
  }

  Future<List<FeedItem>> _restore(int? semester) async {
    final result = await guard(() async {
      final progress = await ref.read(caseRepositoryProvider).all();
      return ref
          .read(feedSnapshotStoreProvider)
          .restore(
            semester: semester,
            showDemoCases: showDemoCases(ref.read(catalogValueProvider)),
            finishedSets: {
              for (final e in progress.entries)
                if (e.value.finished) e.key,
            },
          );
    });
    return switch (result) {
      Ok(:final value) => value,
      Err() => const <FeedItem>[],
    };
  }

  Future<Map<FeedBucket, List<FeedItem>>> _loadPool({
    required DateTime now,
    required bool ahead,
  }) async {
    final progress = await ref.read(caseRepositoryProvider).all();
    return ref
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
          showDemoCases: showDemoCases(ref.read(catalogValueProvider)),
        );
  }

  Future<List<FeedItem>> _fresh({required bool ahead}) async {
    final now = DateTime.now();
    final store = ref.read(feedSeenStoreProvider);
    _seen = await store.load();
    _pool = await _loadPool(now: now, ahead: ahead);
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

  /// After a restored start: build the pool once the first frames are out.
  Future<void> _warmPool({required bool ahead, required String first}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!ref.mounted) {
      return;
    }
    try {
      final now = DateTime.now();
      final store = ref.read(feedSeenStoreProvider);
      _seen = markShown(await store.load(), first, now);
      unawaited(guard(() => store.save(_seen)));
      await store.setLastFirst(first);
      final pool = await _loadPool(now: now, ahead: ahead);
      if (!ref.mounted) {
        return;
      }
      _pool = pool;
      _random = math.Random(now.microsecondsSinceEpoch);
      _topUp();
    } catch (error, stack) {
      appLog.error(error, stack, reason: 'feed pool');
    }
  }

  /// Adds a batch when fewer than 15 posts are left after the current one.
  void _topUp() {
    final list = state.value;
    if (list == null || _pool.isEmpty || _index < list.length - 15) {
      return;
    }
    final more = buildFeedQueue(
      pool: _pool,
      random: _random,
      now: DateTime.now(),
      seen: _seen,
      before: list,
    );
    if (more.isNotEmpty) {
      state = AsyncData([...list, ...more]);
    }
  }

  /// "Shuffle": a new queue, starting from the top.
  Future<void> shuffle() async {
    final ahead = ref.read(feedAheadProvider);
    _index = 0;
    state = await AsyncValue.guard(() => _fresh(ahead: ahead));
  }

  /// The post at [index] is on screen: remember it, top up when needed.
  void shown(int index) {
    final list = state.value;
    if (list == null || index < 0 || index >= list.length) {
      return;
    }
    _index = index;
    _seen = markShown(_seen, list[index].key, DateTime.now());
    unawaited(guard(() => ref.read(feedSeenStoreProvider).save(_seen)));
    _topUp();
  }

  /// How the student did on a post ('right' / 'wrong').
  void outcome(String key, String result) {
    _seen = markOutcome(_seen, key, result, DateTime.now());
    unawaited(guard(() => ref.read(feedSeenStoreProvider).save(_seen)));
  }

  /// End of session (app to background): keep the posts not shown yet, so
  /// the next start opens on them instantly.
  Future<void> saveSnapshot() async {
    final list = state.value;
    if (list == null || !ref.mounted || !ref.read(isSignedInProvider)) {
      return;
    }
    final rest = list.length > _index + 1
        ? list.sublist(_index + 1)
        : const <FeedItem>[];
    await guard(
      () => ref
          .read(feedSnapshotStoreProvider)
          .save(rest, semester: ref.read(currentSemesterProvider)),
    );
  }
}

final feedQueueProvider =
    AsyncNotifierProvider<FeedQueueController, List<FeedItem>>(
      FeedQueueController.new,
    );
