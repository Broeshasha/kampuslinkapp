import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'feed_queue.dart';

const _firstKey = 'feed_last_first';

/// feed_seen (lead brief 2, C). B15: one row per post in feed_seen_entries
/// (schema v2); a save writes only the posts that changed since the last
/// save, instead of re-encoding all of them on every swipe.
class FeedSeenStore {
  FeedSeenStore(this._db);

  static const keep = 3000;

  final AppDatabase _db;
  Map<String, SeenInfo> _saved = const {};
  int _writes = 0;

  Future<String?> _get(String key) async => (await (_db.select(
    _db.keyValues,
  )..where((t) => t.name.equals(key))).getSingleOrNull())?.value;

  Future<void> _set(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(name: Value(key), value: Value(value)),
      );

  Future<Map<String, SeenInfo>> load() async {
    try {
      final rows =
          await (_db.select(_db.feedSeenEntries)
                ..orderBy([(t) => OrderingTerm.desc(t.lastMs)])
                ..limit(keep))
              .get();
      final out = {
        for (final r in rows)
          r.postKey: SeenInfo(
            last: DateTime.fromMillisecondsSinceEpoch(r.lastMs),
            times: r.times,
            today: r.today,
            outcome: r.outcome,
          ),
      };
      _saved = out;
      return out;
    } on Object {
      return {};
    }
  }

  static bool _same(SeenInfo? a, SeenInfo b) =>
      a != null &&
      a.last == b.last &&
      a.times == b.times &&
      a.today == b.today &&
      a.outcome == b.outcome;

  Future<void> save(Map<String, SeenInfo> seen) async {
    final changed = [
      for (final e in seen.entries)
        if (!_same(_saved[e.key], e.value)) e,
    ];
    _saved = seen;
    if (changed.isEmpty) return;
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.feedSeenEntries, [
        for (final e in changed)
          FeedSeenEntriesCompanion.insert(
            postKey: e.key,
            lastMs: e.value.last.millisecondsSinceEpoch,
            times: Value(e.value.times),
            today: Value(e.value.today),
            outcome: Value(e.value.outcome),
          ),
      ]),
    );
    if (++_writes % 200 == 0) await prune();
  }

  /// Keeps only the newest [keep] posts.
  Future<void> prune() => _db.customStatement(
    'DELETE FROM feed_seen_entries WHERE post_key NOT IN '
    '(SELECT post_key FROM feed_seen_entries ORDER BY last_ms DESC LIMIT $keep)',
  );

  Future<String?> lastFirst() => _get(_firstKey);

  Future<void> setLastFirst(String key) => _set(_firstKey, key);
}

/// [seen] after showing [key] at [now].
Map<String, SeenInfo> markShown(
  Map<String, SeenInfo> seen,
  String key,
  DateTime now,
) {
  final old = seen[key];
  final today =
      old != null &&
          old.last.year == now.year &&
          old.last.month == now.month &&
          old.last.day == now.day
      ? old.today + 1
      : 1;
  return {
    ...seen,
    key: SeenInfo(
      last: now,
      times: (old?.times ?? 0) + 1,
      today: today,
      outcome: old?.outcome,
    ),
  };
}

Map<String, SeenInfo> markOutcome(
  Map<String, SeenInfo> seen,
  String key,
  String outcome,
  DateTime now,
) {
  final old = seen[key];
  return {
    ...seen,
    key: SeenInfo(
      last: old?.last ?? now,
      times: old?.times ?? 1,
      today: old?.today ?? 1,
      outcome: outcome,
    ),
  };
}
