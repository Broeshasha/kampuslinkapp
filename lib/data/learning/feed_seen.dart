import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'feed_queue.dart';

const _seenKey = 'feed_seen';
const _firstKey = 'feed_last_first';

/// feed_seen (lead brief 2, C), kept in key_values as one JSON map
/// {key: [last_shown_ms, times_shown, times_on_that_day, last_outcome]}
/// so no schema change is needed. Only the newest [keep] posts are kept.
class FeedSeenStore {
  FeedSeenStore(this._db);

  static const keep = 3000;

  final AppDatabase _db;

  Future<String?> _get(String key) async => (await (_db.select(
    _db.keyValues,
  )..where((t) => t.name.equals(key))).getSingleOrNull())?.value;

  Future<void> _set(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(name: Value(key), value: Value(value)),
      );

  Future<Map<String, SeenInfo>> load() async {
    final raw = await _get(_seenKey);
    if (raw == null) return {};
    try {
      final v = jsonDecode(raw);
      if (v is! Map) return {};
      return {
        for (final e in v.entries)
          if (e.value is List && (e.value as List).length >= 3)
            '${e.key}': SeenInfo(
              last: DateTime.fromMillisecondsSinceEpoch(
                ((e.value as List)[0] as num).toInt(),
              ),
              times: ((e.value as List)[1] as num).toInt(),
              today: ((e.value as List)[2] as num).toInt(),
              outcome: (e.value as List).length > 3
                  ? (e.value as List)[3] as String?
                  : null,
            ),
      };
    } on Object {
      return {};
    }
  }

  Future<void> save(Map<String, SeenInfo> seen) {
    final entries = seen.entries.toList()
      ..sort((a, b) => b.value.last.compareTo(a.value.last));
    return _set(
      _seenKey,
      jsonEncode({
        for (final e in entries.take(keep))
          e.key: [
            e.value.last.millisecondsSinceEpoch,
            e.value.times,
            e.value.today,
            e.value.outcome,
          ],
      }),
    );
  }

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
