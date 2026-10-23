import 'dart:convert';

import 'package:drift/drift.dart';

import '../cases/case_repository.dart';
import '../db/app_database.dart';
import '../lessons/lesson_content.dart';
import '../profile/study_level.dart';
import 'feed_queue.dart';
import 'feed_repository.dart';

/// A quick one-question post (bucket Q).
class FeedQuestion {
  const FeedQuestion({required this.question, required this.module});

  final QuestionRow question;
  final ModuleRow module;

  /// Prompt / options / explanation in [wanted] (else French, else any).
  ({String prompt, List<String> options, String explanation, String language})
  text(String wanted) {
    Map<String, dynamic> i18n;
    try {
      final v = jsonDecode(question.i18nJson);
      i18n = v is Map ? v.cast<String, dynamic>() : const {};
    } on FormatException {
      i18n = const {};
    }
    final lang = pickLanguage(i18n.keys, wanted);
    final t = i18n[lang];
    final m = t is Map ? t.cast<String, dynamic>() : const <String, dynamic>{};
    final options = m['options'];
    return (
      prompt: '${m['prompt'] ?? ''}',
      options: options is List ? [for (final o in options) '$o'] : <String>[],
      explanation: '${m['explanation'] ?? ''}',
      language: lang,
    );
  }
}

const _kindRank = {
  'definition': 0,
  'why': 1,
  'when': 2,
  'trap': 3,
  'formula': 4,
};

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _intOrNull(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Reads the local database and sorts every possible post into its bucket
/// (lead brief 2, C), current semester only (WP17-A). Everything is local
/// and works offline.
class FeedPoolLoader {
  FeedPoolLoader(this._db, this._feed, this._cases);

  final AppDatabase _db;
  final FeedRepository _feed;
  final CaseRepository _cases;

  Future<Map<String, Map<String, dynamic>>> _meta() async {
    final rows = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.like('meta:%'))).get();
    final out = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      try {
        final v = jsonDecode(r.value);
        if (v is! Map) continue;
        for (final part in const ['c', 'q']) {
          final m = v[part];
          if (m is! Map) continue;
          for (final e in m.entries) {
            if (e.value is Map) {
              out['$part:${e.key}'] = (e.value as Map).cast<String, dynamic>();
            }
          }
        }
      } on FormatException {
        continue;
      }
    }
    return out;
  }

  /// The lessons whose new cards may enter the feed: per module, the lesson
  /// the student is on (Continue, else the first unfinished one) and the
  /// next one ("soft unlock").
  Future<({Set<int> allowed, Map<int, int> rank})> _openLessons() async {
    final lessons = await _db.select(_db.lessons).get();
    final done = {
      for (final p in await _db.select(_db.lessonProgress).get())
        if (p.completed) p.lessonId,
    };
    final reading = await _db.select(_db.readingPositions).get()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final byModule = <int, List<LessonRow>>{};
    for (final l in lessons) {
      byModule.putIfAbsent(l.moduleId, () => []).add(l);
    }
    final lessonModule = {for (final l in lessons) l.id: l.moduleId};
    // Module of the most recent reading first.
    final moduleOrder = <int>[];
    for (final r in reading) {
      final m = lessonModule[r.lessonId];
      if (m != null && !moduleOrder.contains(m)) moduleOrder.add(m);
    }
    for (final m in byModule.keys.toList()..sort()) {
      if (!moduleOrder.contains(m)) moduleOrder.add(m);
    }
    final allowed = <int>{};
    final rank = <int, int>{};
    for (final m in moduleOrder) {
      final list = byModule[m]!
        ..sort((a, b) => a.position.compareTo(b.position));
      rank[m] = moduleOrder.indexOf(m);
      int? current;
      for (final r in reading) {
        if (lessonModule[r.lessonId] == m &&
            r.progress >= 0.02 &&
            r.progress <= 0.98 &&
            !done.contains(r.lessonId)) {
          current = r.lessonId;
          break;
        }
      }
      current ??= list
          .where((l) => !done.contains(l.id))
          .map((l) => l.id)
          .firstOrNull;
      if (current == null) continue;
      final i = list.indexWhere((l) => l.id == current);
      allowed.add(current);
      if (i >= 0 && i + 1 < list.length) allowed.add(list[i + 1].id);
    }
    return (allowed: allowed, rank: rank);
  }

  Future<Map<FeedBucket, List<FeedItem>>> load({
    required DateTime now,
    bool ahead = false,
    Map<String, bool> finishedSets = const {},
    Set<String> startedSets = const {},
    int? semester,
  }) async {
    final meta = await _meta();
    final open = await _openLessons();
    // WP17-A, A3: every bucket uses ONLY current-semester modules.
    final modules = {
      for (final m in await _db.select(_db.modules).get()) m.id: m,
    };
    final cards = [
      for (final c in await _feed.allCards())
        if (inSemester(modules[c.module.id] ?? c.module, semester)) c,
    ];
    final known = <FeedItem>[];
    final due = <FeedItem>[];
    final fresh = <FeedCard>[];
    final knownConcepts = <String>{};
    final lessonsSeen = <int>{};
    final lessonsKnown = <int>{};

    for (final c in cards) {
      final m = meta['c:${c.card.id}'] ?? const <String, dynamic>{};
      final p = c.progress;
      if (p == null || (p.lastReviewedAt == null && p.dueAt == null)) {
        if (open.allowed.contains(c.card.lessonId)) fresh.add(c);
        continue;
      }
      lessonsSeen.add(c.card.lessonId);
      final item = FeedItem(
        key: 'c:${c.card.id}',
        bucket: p.box >= 3 ? FeedBucket.known : FeedBucket.due,
        concept: _str(m['concept']),
        lessonId: c.card.lessonId,
        cardKind: _str(m['card_kind']),
        difficulty: _intOrNull(m['difficulty']) ?? 2,
        payload: c,
      );
      if (p.box >= 3) {
        known.add(item);
        lessonsKnown.add(c.card.lessonId);
        if (item.concept != null) knownConcepts.add(item.concept!);
      } else {
        final at = p.dueAt;
        if (ahead || at == null || !at.isAfter(now)) due.add(item);
      }
    }

    int rankOf(FeedCard c) => open.rank[c.module.id] ?? 999;
    int diff(FeedCard c) =>
        _intOrNull(meta['c:${c.card.id}']?['difficulty']) ?? 2;
    int kind(FeedCard c) =>
        _kindRank[meta['c:${c.card.id}']?['card_kind']] ?? 2;
    fresh.sort((a, b) {
      for (final d in [
        rankOf(a).compareTo(rankOf(b)),
        a.lessonPosition.compareTo(b.lessonPosition),
        diff(a).compareTo(diff(b)),
        kind(a).compareTo(kind(b)),
        a.card.position.compareTo(b.card.position),
      ]) {
        if (d != 0) return d;
      }
      return a.card.id.compareTo(b.card.id);
    });
    final freshItems = [
      for (var i = 0; i < fresh.length; i++)
        FeedItem(
          key: 'c:${fresh[i].card.id}',
          bucket: FeedBucket.fresh,
          concept: _str(meta['c:${fresh[i].card.id}']?['concept']),
          lessonId: fresh[i].card.lessonId,
          cardKind: _str(meta['c:${fresh[i].card.id}']?['card_kind']),
          difficulty: diff(fresh[i]),
          order: i,
          payload: fresh[i],
        ),
    ];

    // Q: quick questions about what the student knows (or just saw).
    final done = {
      for (final p in await _db.select(_db.lessonProgress).get())
        if (p.completed) p.lessonId,
    };
    final quick = <FeedItem>[];
    for (final q in await _db.select(_db.questions).get()) {
      if (q.kind != 'mcq') continue;
      final module = modules[q.moduleId];
      if (module == null || !inSemester(module, semester)) continue;
      final m = meta['q:${q.id}'] ?? const <String, dynamic>{};
      final concept = _str(m['concept']);
      final eligible =
          (concept != null && knownConcepts.contains(concept)) ||
          lessonsKnown.contains(q.lessonId) ||
          done.contains(q.lessonId) ||
          (known.isEmpty && lessonsSeen.contains(q.lessonId));
      if (!eligible) continue;
      quick.add(
        FeedItem(
          key: 'q:${q.id}',
          bucket: FeedBucket.quick,
          concept: concept,
          lessonId: q.lessonId,
          difficulty: _intOrNull(m['difficulty']) ?? 2,
          payload: FeedQuestion(question: q, module: module),
        ),
      );
    }

    // S: carousel sets, finished ones left out.
    final sets = <FeedItem>[];
    final sources = await _cases.sources();
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      if (finishedSets[s.id] ?? false) continue;
      if (!inSemester(modules[s.moduleId], semester)) continue;
      sets.add(
        FeedItem(
          key: 's:${s.id}',
          bucket: FeedBucket.set,
          lessonId: s.lessonId,
          order: i,
          started: startedSets.contains(s.id),
          payload: s,
        ),
      );
    }

    return {
      FeedBucket.known: known,
      FeedBucket.due: due,
      FeedBucket.fresh: freshItems,
      FeedBucket.set: sets,
      FeedBucket.quick: quick,
    };
  }
}
