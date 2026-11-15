import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// MOT-2: one readiness bar per bac subject (app_config bac_subjects).
/// Per chapter (lesson unit): 70% cards known well (box >= 3) + 30% lessons
/// done; chapters without cards use lessons only. Every chapter counts the
/// same, also across the modules of one bar (PHY + CHEM = one bar).
class BacSubject {
  const BacSubject({required this.key, required this.modules, required this.coef});

  final String key;
  final List<int> modules;
  final int coef;

  static List<BacSubject> listFrom(Object? config, Set<int> visible) {
    if (config is! Map) return const [];
    final out = <BacSubject>[];
    for (final stream in config.values) {
      if (stream is! List) continue;
      for (final e in stream) {
        if (e is! Map) continue;
        final modules = [
          for (final m in e['modules'] is List ? e['modules'] as List : const [])
            if (m is num) m.toInt(),
        ];
        if (modules.isEmpty || !modules.any(visible.contains)) continue;
        final c = e['coef'];
        out.add(
          BacSubject(
            key: '${e['key'] ?? ''}',
            modules: modules,
            coef: c is num ? c.toInt() : 1,
          ),
        );
      }
    }
    return out;
  }
}

class SubjectReadiness {
  const SubjectReadiness(this.subject, this.value);

  final BacSubject subject;

  /// 0..1
  final double value;
}

String _chapterKey(LessonRow l) {
  final raw = l.unitJson;
  if (raw != null) {
    try {
      final u = jsonDecode(raw);
      if (u is Map) {
        final k = u['ref'] ?? u['number'];
        if (k != null && '$k'.isNotEmpty) return '${l.moduleId}:$k';
      }
    } on FormatException {
      // fall through: the lesson is its own chapter
    }
  }
  return '${l.moduleId}:L${l.id}';
}

Future<List<SubjectReadiness>> bacReadiness(
  AppDatabase db,
  List<BacSubject> subjects,
) async {
  if (subjects.isEmpty) return const [];
  final ids = {for (final s in subjects) ...s.modules}.toList();
  final lessons = await (db.select(db.lessons)..where((t) => t.moduleId.isIn(ids))).get();
  final done = {
    for (final p in await (db.select(db.lessonProgress)..where((t) => t.completed.equals(true))).get())
      p.lessonId,
  };
  final cards = await (db.select(db.cards)..where((t) => t.moduleId.isIn(ids))).get();
  final known = {
    for (final p in await (db.select(db.cardProgress)..where((t) => t.box.isBiggerOrEqualValue(3))).get())
      p.cardId,
  };
  final chapterOf = {for (final l in lessons) l.id: _chapterKey(l)};
  // chapter -> [lessons, lessonsDone, cards, cardsKnown]
  final stats = <String, List<int>>{};
  for (final l in lessons) {
    final s = stats.putIfAbsent(chapterOf[l.id]!, () => [0, 0, 0, 0]);
    s[0]++;
    if (done.contains(l.id)) s[1]++;
  }
  for (final c in cards) {
    final ch = chapterOf[c.lessonId];
    if (ch == null) continue;
    final s = stats[ch]!;
    s[2]++;
    if (known.contains(c.id)) s[3]++;
  }
  double score(List<int> s) {
    final lessonPart = s[0] == 0 ? 0.0 : s[1] / s[0];
    if (s[2] == 0) return lessonPart;
    return 0.7 * (s[3] / s[2]) + 0.3 * lessonPart;
  }

  return [
    for (final sub in subjects)
      () {
        final chapters = [
          for (final e in stats.entries)
            if (sub.modules.any((m) => e.key.startsWith('$m:'))) score(e.value),
        ];
        final v = chapters.isEmpty ? 0.0 : chapters.reduce((a, b) => a + b) / chapters.length;
        return SubjectReadiness(sub, v.clamp(0.0, 1.0));
      }(),
  ];
}

/// Countdown: exact days only once the date is confirmed (app_config
/// bac_date_confirmed), else whole weeks. null = no date / already passed.
({int value, bool days})? bacCountdown(Object? date, Object? confirmed, DateTime now) {
  final at = DateTime.tryParse('${date ?? ''}');
  if (at == null) return null;
  final left = at.toUtc().difference(now.toUtc());
  if (left.isNegative) return null;
  if (confirmed == true) return (value: (left.inHours / 24).ceil(), days: true);
  return (value: (left.inDays / 7).round().clamp(1, 1000), days: false);
}
