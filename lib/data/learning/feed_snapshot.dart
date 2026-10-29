import 'dart:convert';

import 'package:drift/drift.dart';

import '../cases/case_repository.dart';
import '../db/app_database.dart';
import '../profile/study_level.dart';
import 'feed_pool.dart';
import 'feed_queue.dart';
import 'feed_repository.dart';

const feedSnapshotKey = 'feed_next_v1';

/// The next posts, saved when the app goes to the background, so the next
/// start shows them at once (no pool to build first). Read once: the
/// snapshot is deleted when it is restored.
class FeedSnapshotStore {
  FeedSnapshotStore(this._db, this._cases, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final CaseRepository _cases;
  final DateTime Function() _now;

  static const maxItems = 40;
  static const maxAge = Duration(days: 3);

  Future<void> save(List<FeedItem> items, {required int? semester}) async {
    if (items.isEmpty) {
      await clear();
      return;
    }
    final value = jsonEncode({
      'semester': semester,
      'at': _now().toIso8601String(),
      'items': [
        for (final i in items.take(maxItems)) {'k': i.key, 'b': i.bucket.name},
      ],
    });
    await _db
        .into(_db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion(
            name: const Value(feedSnapshotKey),
            value: Value(value),
          ),
        );
  }

  Future<void> clear() async {
    await (_db.delete(
      _db.keyValues,
    )..where((t) => t.name.equals(feedSnapshotKey))).go();
  }

  /// The saved posts, in order, rebuilt from the local tables. Posts whose
  /// content is gone, or outside [semester], are dropped.
  Future<List<FeedItem>> restore({
    required int? semester,
    bool showDemoCases = false,
    Set<String> finishedSets = const {},
  }) async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.equals(feedSnapshotKey))).getSingleOrNull();
    if (row == null) {
      return const [];
    }
    Map<String, dynamic> snap;
    try {
      final v = jsonDecode(row.value);
      if (v is! Map) {
        return const [];
      }
      snap = v.cast<String, dynamic>();
    } on FormatException {
      return const [];
    }
    if (snap['semester'] != semester) {
      return const [];
    }
    final at = DateTime.tryParse('${snap['at']}');
    if (at == null || _now().difference(at) > maxAge) {
      await clear();
      return const [];
    }
    // Used once: gone after this read (a wrong semester above keeps it for
    // the build that has the right one).
    await clear();
    final raw = snap['items'];
    if (raw is! List) {
      return const [];
    }
    final buckets = FeedBucket.values.asNameMap();
    final entries = <({String key, FeedBucket bucket})>[];
    for (final e in raw) {
      if (e is! Map) {
        continue;
      }
      final key = '${e['k'] ?? ''}';
      if (key.length < 3) {
        continue;
      }
      entries.add((key: key, bucket: buckets['${e['b']}'] ?? FeedBucket.known));
    }
    int? idOf(String key) => int.tryParse(key.substring(2));
    final cardIds = <int>{};
    final questionIds = <int>{};
    var hasSets = false;
    for (final e in entries) {
      final id = idOf(e.key);
      if (e.key.startsWith('c:') && id != null) {
        cardIds.add(id);
      } else if (e.key.startsWith('q:') && id != null) {
        questionIds.add(id);
      } else if (e.key.startsWith('s:')) {
        hasSets = true;
      }
    }

    final modules = {
      for (final m in await _db.select(_db.modules).get()) m.id: m,
    };
    final cards = <int, FeedCard>{};
    if (cardIds.isNotEmpty) {
      final rows =
          await (_db.select(_db.cards)..where((t) => t.id.isIn(cardIds))).join([
            innerJoin(
              _db.modules,
              _db.modules.id.equalsExp(_db.cards.moduleId),
            ),
            leftOuterJoin(
              _db.lessons,
              _db.lessons.id.equalsExp(_db.cards.lessonId),
            ),
            leftOuterJoin(
              _db.cardProgress,
              _db.cardProgress.cardId.equalsExp(_db.cards.id),
            ),
          ]).get();
      for (final r in rows) {
        final card = r.readTable(_db.cards);
        cards[card.id] = FeedCard(
          card: card,
          module: r.readTable(_db.modules),
          lessonPosition: r.readTableOrNull(_db.lessons)?.position ?? 0,
          progress: r.readTableOrNull(_db.cardProgress),
        );
      }
    }
    final questions = <int, QuestionRow>{};
    if (questionIds.isNotEmpty) {
      final rows = await (_db.select(
        _db.questions,
      )..where((t) => t.id.isIn(questionIds))).get();
      for (final q in rows) {
        questions[q.id] = q;
      }
    }
    final sets = <String, CaseSource>{};
    if (hasSets) {
      for (final s in await _cases.sources(includeDemo: showDemoCases)) {
        sets[s.id] = s;
      }
    }

    final out = <FeedItem>[];
    for (final e in entries) {
      if (e.key.startsWith('c:')) {
        final c = cards[idOf(e.key)];
        if (c == null ||
            !inSemester(modules[c.module.id] ?? c.module, semester)) {
          continue;
        }
        out.add(
          FeedItem(
            key: e.key,
            bucket: e.bucket,
            lessonId: c.card.lessonId,
            payload: c,
          ),
        );
      } else if (e.key.startsWith('q:')) {
        final q = questions[idOf(e.key)];
        final module = q == null ? null : modules[q.moduleId];
        if (q == null || module == null || !inSemester(module, semester)) {
          continue;
        }
        out.add(
          FeedItem(
            key: e.key,
            bucket: e.bucket,
            lessonId: q.lessonId,
            payload: FeedQuestion(question: q, module: module),
          ),
        );
      } else if (e.key.startsWith('s:')) {
        final s = sets[e.key.substring(2)];
        if (s == null || finishedSets.contains(s.id)) {
          continue;
        }
        final demo = showDemoCases && s.moduleId == null;
        if (!demo && !inSemester(modules[s.moduleId], semester)) {
          continue;
        }
        out.add(
          FeedItem(
            key: e.key,
            bucket: e.bucket,
            lessonId: s.lessonId,
            payload: s,
          ),
        );
      }
    }
    return out;
  }
}
