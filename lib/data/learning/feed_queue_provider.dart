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
import '../../core/l10n/locale_controller.dart';
import 'feed_pool.dart';
import 'feed_progress.dart';
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

const _moduleKey = 'home_feed_module';
const _algoKey = 'feed_algo';

/// Bump when the feed logic changes: the posts saved by the old logic are
/// thrown away once instead of being shown first.
const _feedAlgo = 2;

/// The Home chip: null = All, else one module id. Remembered on the phone.
class FeedModule extends Notifier<int?> {
  @override
  int? build() {
    try {
      return ref.read(sharedPrefsProvider).getInt(_moduleKey);
    } catch (_) {
      return null;
    }
  }

  void set(int? module) {
    state = module;
    try {
      final prefs = ref.read(sharedPrefsProvider);
      if (module == null) {
        prefs.remove(_moduleKey);
      } else {
        prefs.setInt(_moduleKey, module);
      }
    } catch (_) {
      // Not remembered: harmless.
    }
  }
}

final feedModuleProvider = NotifierProvider<FeedModule, int?>(FeedModule.new);

/// The Home feed queue (lead brief 2 + feed brief A/B). Never reordered
/// under the finger: it only grows at the end and is rebuilt on "shuffle",
/// "practise ahead", or when new content arrives while it is empty.
///
/// One queue per chip (All + one per module), built from the same pool in
/// the background, so switching chips is instant. No post twice in one
/// session (across chips too).
///
/// Fast start: the posts saved at the end of the last session (snapshot)
/// are shown at once; the full pool is built afterwards, in the background.
class FeedQueueController extends AsyncNotifier<List<FeedItem>> {
  Map<FeedBucket, List<FeedItem>> _pool = const {};
  Map<String, SeenInfo> _seen = {};
  math.Random _random = math.Random();
  int? _module;
  final _queues = <int?, List<FeedItem>>{};
  final _indexes = <int?, int>{};
  final _session = <String>{};
  bool _reloading = false;

  /// The list last put on screen. Kept here because reading `state` inside
  /// build() on a rebuild throws CircularDependencyError.
  List<FeedItem>? _current;

  int get _index => _indexes[_module] ?? 0;

  /// Start-up trace: how many times the queue was built (a rebuild during
  /// start-up costs a full pool build).
  static int _builds = 0;
  static String? _lastParams;

  /// B01: another student signed in, start the trace from zero.
  static void resetTrace() {
    _builds = 0;
    _lastParams = null;
  }

  @override
  Future<List<FeedItem>> build() async {
    if (!ref.watch(isSignedInProvider)) {
      return const [];
    }
    final build = ++_builds;
    final ahead = ref.watch(feedAheadProvider);
    // A new semester rebuilds the whole queue at once (WP17-A).
    final semester = ref.watch(currentSemesterProvider);
    startupTrace.mark('feed build #$build', 'semester $semester');
    _module = ref.read(feedModuleProvider);
    final visible = ref.read(visibleModuleIdsProvider);
    if (_module != null && visible.isNotEmpty && !visible.contains(_module)) {
      _module = null;
    }
    // Rebuilt with the same semester (a provider woke up during start-up):
    // keep the posts already on screen instead of starting over.
    final params = '$semester|$ahead';
    final previous = _current;
    if (_lastParams == params && previous != null && previous.isNotEmpty) {
      startupTrace.mark('feed kept #$build', '${previous.length} posts');
      unawaited(_warmPool(ahead: ahead, first: previous.first.key));
      return previous;
    }
    _lastParams = params;
    ref.listen<String>(downloadedKeyProvider, (previous, next) {
      if (previous != next && (state.value?.isEmpty ?? false)) {
        ref.invalidateSelf();
      }
    });
    _queues.clear();
    _indexes.clear();
    _session.clear();
    _pool = const {};
    var oldAlgo = false;
    try {
      final prefs = ref.read(sharedPrefsProvider);
      oldAlgo = prefs.getInt(_algoKey) != _feedAlgo;
      if (oldAlgo) await prefs.setInt(_algoKey, _feedAlgo);
    } catch (_) {
      // No prefs (tests): keep the snapshot.
    }
    if (!ahead && !oldAlgo) {
      final restored = _onlyModule(await _restore(semester), _module);
      startupTrace.mark('feed snapshot #$build', '${restored.length} posts');
      if (restored.isNotEmpty) {
        _queues[_module] = restored;
        unawaited(_warmPool(ahead: ahead, first: restored.first.key));
        _current = restored;
        return restored;
      }
    }
    final fresh = await _fresh(ahead: ahead);
    startupTrace.mark('feed full build #$build', '${fresh.length} posts');
    _current = fresh;
    return fresh;
  }

  List<FeedItem> _onlyModule(List<FeedItem> items, int? module) => [
    for (final i in items)
      if ((module == null || feedItemModule(i) == module) &&
          !_session.contains(i.key))
        i,
  ];

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
          seen: _seen,
        );
  }

  /// One batch for [module] from the pool, never a post of this session.
  List<FeedItem> _batch(
    int? module, {
    List<FeedItem> before = const [],
    String? lastFirst,
  }) => buildFeedQueue(
    pool: filterPool(_pool, module, moduleOf: feedItemModule),
    random: _random,
    now: DateTime.now(),
    seen: _seen,
    lastFirst: lastFirst,
    before: before,
    shares: progressFeedShares,
    repeat: false,
    exclude: _session,
    proportionalFill: true,
  );

  /// Queues for the other chips, built ahead (instant switching).
  void _prebuild() {
    final ids = <int?>[null, ...ref.read(visibleModuleIdsProvider)];
    for (final id in ids) {
      if (!_queues.containsKey(id)) {
        _queues[id] = _batch(id);
        _indexes[id] = 0;
      }
    }
  }

  Future<List<FeedItem>> _fresh({required bool ahead}) async {
    final now = DateTime.now();
    final store = ref.read(feedSeenStoreProvider);
    _seen = await store.load();
    _pool = await _loadPool(now: now, ahead: ahead);
    _random = math.Random(now.microsecondsSinceEpoch);
    final list = _batch(_module, lastFirst: await store.lastFirst());
    _queues[_module] = list;
    _indexes[_module] = 0;
    if (list.isNotEmpty) {
      _session.add(list.first.key);
      await store.setLastFirst(list.first.key);
      _seen = markShown(_seen, list.first.key, now);
      unawaited(guard(() => store.save(_seen)));
    }
    _prebuild();
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
      _session.add(first);
      _seen = markShown(await store.load(), first, now);
      unawaited(guard(() => store.save(_seen)));
      await store.setLastFirst(first);
      final pool = await _loadPool(now: now, ahead: ahead);
      if (!ref.mounted) {
        return;
      }
      _pool = pool;
      _random = math.Random(now.microsecondsSinceEpoch);
      _prebuild();
      _topUp();
    } catch (error, stack) {
      appLog.error(error, stack, reason: 'feed pool');
    }
  }

  /// Adds a batch when fewer than 15 posts are left after the current one.
  /// When the pool has nothing new, it is rebuilt once (the frontier may
  /// have moved forward).
  void _topUp() {
    final list = state.value;
    if (list == null || _pool.isEmpty || _index < list.length - 15) {
      return;
    }
    if (!_append(list) && !_reloading) {
      unawaited(_reloadAndAppend());
    }
  }

  bool _append(List<FeedItem> list) {
    final more = _batch(_module, before: list);
    if (more.isEmpty) return false;
    final next = [...list, ...more];
    _queues[_module] = next;
    _current = next;
    state = AsyncData(next);
    return true;
  }

  Future<void> _reloadAndAppend() async {
    _reloading = true;
    try {
      final pool = await _loadPool(
        now: DateTime.now(),
        ahead: ref.read(feedAheadProvider),
      );
      if (!ref.mounted) return;
      _pool = pool;
      // Other chips are rebuilt from the new pool when opened.
      _queues.removeWhere((k, _) => k != _module);
      final list = state.value;
      if (list != null) _append(list);
    } catch (error, stack) {
      appLog.error(error, stack, reason: 'feed reload');
    } finally {
      _reloading = false;
    }
  }

  /// Home chip tapped: show that chip's queue at once (posts already seen
  /// in this session are skipped). Never a spinner.
  void select(int? module) {
    ref.read(feedModuleProvider.notifier).set(module);
    if (module == _module) return;
    _indexes[_module] = _index;
    _module = module;
    final cached = _queues[module];
    final List<FeedItem> list;
    if (cached != null) {
      list = _onlyModule(cached, module);
    } else if (_pool.isNotEmpty) {
      list = _batch(module);
    } else {
      list = _onlyModule(state.value ?? const [], module);
    }
    _queues[module] = list;
    _indexes[module] = 0;
    _current = list;
    state = AsyncData(list);
    if (list.isNotEmpty) shown(0);
  }

  /// "Shuffle": a new queue (new session), starting from the top.
  Future<void> shuffle() async {
    final ahead = ref.read(feedAheadProvider);
    _queues.clear();
    _indexes.clear();
    _session.clear();
    state = await AsyncValue.guard(() => _fresh(ahead: ahead));
    _current = state.value;
  }

  /// The post at [index] is on screen: remember it, top up when needed.
  void shown(int index) {
    final list = state.value;
    if (list == null || index < 0 || index >= list.length) {
      return;
    }
    _indexes[_module] = index;
    _session.add(list[index].key);
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
