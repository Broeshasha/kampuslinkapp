import 'dart:convert';

import 'package:drift/drift.dart';

import '../cases/case_repository.dart';
import '../db/app_database.dart';
import '../lessons/lesson_content.dart';
import '../profile/study_level.dart';
import 'content_meta.dart';
import 'feed_progress.dart';
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

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _intOrNull(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

const _frontierKey = 'feed_frontier';

/// The module of a post (cards, quick questions, sets; null = demo set).
int? feedItemModule(FeedItem i) =>
    i.moduleId ??
    switch (i.payload) {
      final FeedCard c => c.module.id,
      final FeedQuestion q => q.module.id,
      final CaseSource s => s.moduleId,
      _ => null,
    };

String _unitKey(LessonRow l) {
  try {
    final v = jsonDecode(l.unitJson ?? '');
    if (v is Map) {
      final k = v['ref'] ?? v['number'] ?? v['id'];
      if (k != null && '$k'.isNotEmpty) return 'u:$k';
    }
  } on FormatException {
    // No unit: the lesson is its own chapter.
  }
  return 'l:${l.id}';
}

/// Lesson id -> chapter index inside its module (units in lesson order; a
/// lesson without a unit is its own chapter).
Map<int, int> chapterIndexOf(List<LessonRow> lessons) {
  final byModule = <int, List<LessonRow>>{};
  for (final l in lessons) {
    byModule.putIfAbsent(l.moduleId, () => []).add(l);
  }
  final out = <int, int>{};
  for (final list in byModule.values) {
    list.sort(
      (a, b) => a.position != b.position
          ? a.position.compareTo(b.position)
          : a.id.compareTo(b.id),
    );
    final keys = <String>[];
    for (final l in list) {
      final k = _unitKey(l);
      if (!keys.contains(k)) keys.add(k);
      out[l.id] = keys.indexOf(k);
    }
  }
  return out;
}

/// Reads the local database and sorts every possible post into its bucket,
/// current semester only (WP17-A). Cards follow the per-module FRONTIER
/// chapter (feed brief A): 70% new cards of the frontier (then frontier+1),
/// 30% review. Everything is local and works offline.
class FeedPoolLoader {
  FeedPoolLoader(this._db, this._feed, this._cases);

  final AppDatabase _db;
  final FeedRepository _feed;
  final CaseRepository _cases;

  /// Same decoding as the Home cards (off the UI thread when big).
  Future<Map<String, Map<String, dynamic>>> _meta() => loadContentMeta(_db);

  /// Frontier chapter per module, kept in Drift (key_values) and
  /// recomputed from the card progress at every load, so a reinstall +
  /// server restore finds it again. It never goes back.
  Future<Map<int, int>> _storedFrontiers() async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.equals(_frontierKey))).getSingleOrNull();
    if (row == null) return const {};
    try {
      final v = jsonDecode(row.value);
      if (v is! Map) return const {};
      return {
        for (final e in v.entries)
          if (int.tryParse('${e.key}') != null && e.value is num)
            int.parse('${e.key}'): (e.value as num).toInt(),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> _saveFrontiers(Map<int, int> f) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(
          name: const Value(_frontierKey),
          value: Value(
            jsonEncode({for (final e in f.entries) '${e.key}': e.value}),
          ),
        ),
      );

  Future<Map<FeedBucket, List<FeedItem>>> load({
    required DateTime now,
    bool ahead = false,
    Map<String, bool> finishedSets = const {},
    Set<String> startedSets = const {},
    int? semester,
    bool showDemoCases = false,
    Map<String, SeenInfo> seen = const {},
  }) async {
    final meta = await _meta();
    // WP17-A, A3: every bucket uses ONLY current-semester modules.
    final modules = {
      for (final m in await _db.select(_db.modules).get()) m.id: m,
    };
    final cards = [
      for (final c in await _feed.allCards())
        if (inSemester(modules[c.module.id] ?? c.module, semester)) c,
    ];
    final lessons = await _db.select(_db.lessons).get();
    final chapterOf = chapterIndexOf(lessons);
    final done = {
      for (final p in await _db.select(_db.lessonProgress).get())
        if (p.completed) p.lessonId,
    };
    final reading = {
      for (final r in await _db.select(_db.readingPositions).get())
        r.lessonId: r.progress,
    };
    final knownConcepts = <String>{};
    final lessonsSeen = <int>{};
    final lessonsKnown = <int>{};
    var anyKnown = false;
    final facts = <CardFacts>[];
    for (final c in cards) {
      final key = 'c:${c.card.id}';
      final m = meta[key] ?? const <String, dynamic>{};
      final p = c.progress;
      final isSeen = p != null && (p.lastReviewedAt != null || p.dueAt != null);
      final outcome = seen[key]?.outcome;
      final box = p?.box ?? 1;
      if (isSeen) {
        lessonsSeen.add(c.card.lessonId);
        if (box >= 3) {
          anyKnown = true;
          lessonsKnown.add(c.card.lessonId);
          final concept = _str(m['concept']);
          if (concept != null) knownConcepts.add(concept);
        }
      }
      facts.add(
        CardFacts(
          key: key,
          moduleId: c.module.id,
          chapter: chapterOf[c.card.lessonId] ?? 0,
          lessonId: c.card.lessonId,
          lessonPosition: c.lessonPosition,
          position: c.card.position,
          cardKind: _str(m['card_kind']),
          difficulty: _intOrNull(m['difficulty']) ?? 2,
          concept: _str(m['concept']),
          box: box,
          seen: isSeen,
          rightOnce: isSeen && (box >= 2 || outcome == 'right'),
          wrongCount:
              (outcome == 'wrong' ? 1 : 0) + (isSeen && box <= 1 ? 1 : 0),
          dueAt: p?.dueAt,
          lastSeen: p?.lastReviewedAt ?? seen[key]?.last,
          lessonRead:
              done.contains(c.card.lessonId) ||
              (reading[c.card.lessonId] ?? 0) >= 0.5,
          payload: c,
        ),
      );
    }
    final stored = await _storedFrontiers();
    final frontier = computeFrontiers(facts, stored: stored);
    final merged = {...stored, ...frontier};
    if (merged.length != stored.length ||
        merged.entries.any((e) => stored[e.key] != e.value)) {
      await _saveFrontiers(merged);
    }
    final buckets = progressBuckets(
      facts,
      frontiers: frontier,
      now: now,
      ahead: ahead,
    );

    // Q: quick questions about what the student knows (or just saw).
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
          (!anyKnown && lessonsSeen.contains(q.lessonId));
      if (!eligible) continue;
      quick.add(
        FeedItem(
          key: 'q:${q.id}',
          bucket: FeedBucket.quick,
          concept: concept,
          lessonId: q.lessonId,
          difficulty: _intOrNull(m['difficulty']) ?? 2,
          moduleId: module.id,
          payload: FeedQuestion(question: q, module: module),
        ),
      );
    }

    // S: carousel sets, finished ones left out.
    final sets = <FeedItem>[];
    final sources = await _cases.sources(includeDemo: showDemoCases);
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      if (finishedSets[s.id] ?? false) continue;
      final demo = showDemoCases && s.moduleId == null;
      if (!demo && !inSemester(modules[s.moduleId], semester)) continue;
      sets.add(
        FeedItem(
          key: 's:${s.id}',
          bucket: FeedBucket.set,
          lessonId: s.lessonId,
          order: i,
          started: startedSets.contains(s.id),
          moduleId: s.moduleId,
          payload: s,
        ),
      );
    }

    return {
      FeedBucket.known: const <FeedItem>[],
      FeedBucket.due: buckets.review,
      FeedBucket.fresh: buckets.fresh,
      FeedBucket.set: sets,
      FeedBucket.quick: quick,
    };
  }
}
