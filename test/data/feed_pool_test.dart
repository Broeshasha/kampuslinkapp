import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/cases/case_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_pool.dart';
import 'package:kampuslink/data/learning/feed_queue.dart';
import 'package:kampuslink/data/learning/feed_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:kampuslink/features/cases/case_models.dart';

/// Module 7: 4 lessons x 3 cards (file 13 fields on the cards), one MCQ per
/// lesson, and one carousel set in the server shape (texts under i18n).
Map<String, dynamic> bundle() => {
  'schema_version': 3,
  'module': {'id': 7, 'name': 'Stats', 'semester': 3},
  'version': 1,
  'languages': ['fr'],
  'lessons': [
    for (var l = 1; l <= 4; l++)
      {
        'id': l,
        'position': l,
        'i18n': {
          'fr': {'title': 'L$l'},
        },
        'cards': [
          for (var c = 1; c <= 3; c++)
            {
              'id': l * 10 + c,
              'position': c,
              'concept': 'ch$l:c$c',
              'difficulty': 4 - c,
              'card_kind': c == 1 ? 'formula' : 'definition',
              'i18n': {
                'fr': {'front': 'f', 'back': 'b'},
              },
            },
        ],
        'questions': [
          {
            'id': 100 + l,
            'kind': 'mcq',
            'correct_index': 0,
            'position': 1,
            'concept': 'ch$l:c1',
            'i18n': {
              'fr': {
                'prompt': 'p',
                'options': ['a', 'b'],
              },
            },
          },
        ],
      },
  ],
  'resources': const [],
  'glossary': const [],
  'sets': [
    {
      'id': 'set_1',
      'kind': 'mystery',
      'position': 1,
      'lesson_id': 1,
      'i18n': {
        'fr': {
          'title': 'Le cas',
          'slides': [
            {'id': 'a', 'role': 'hook', 'title': 'Pourquoi ?'},
            {
              'id': 'b',
              'role': 'commit',
              'prompt': 'Ton avis',
              'options': ['x', 'y'],
              'correct_index': 1,
            },
            {
              'id': 'c',
              'role': 'reveal',
              'content': 'Parce que',
              'exam_note': 'Tombe souvent',
            },
          ],
        },
      },
    },
  ],
};

void main() {
  late AppDatabase db;
  late FeedPoolLoader loader;
  final now = DateTime(2026, 10, 21, 12);

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxRepository(db, now: () => now);
    loader = FeedPoolLoader(
      db,
      FeedRepository(db, outbox, now: () => now),
      CaseRepository(db, outbox),
    );
    await BundleImporter(db).importBundle(bundle());
  });
  tearDown(() => db.close());

  Future<void> progress(int cardId, int box, DateTime? due) => db
      .into(db.cardProgress)
      .insertOnConflictUpdate(
        CardProgressCompanion(
          cardId: Value(cardId),
          box: Value(box),
          dueAt: Value(due),
          lastReviewedAt: Value(now.subtract(const Duration(days: 2))),
        ),
      );

  test('a new student: new cards of lessons 1-2 only, easiest first', () async {
    final pool = await loader.load(now: now);
    expect(pool[FeedBucket.known], isEmpty);
    expect(pool[FeedBucket.due], isEmpty);
    expect(pool[FeedBucket.quick], isEmpty);
    final fresh = pool[FeedBucket.fresh]!;
    expect(fresh.map((i) => i.lessonId).toSet(), {1, 2});
    // difficulty 1 (card 3) first, the formula card (difficulty 3) last.
    expect(fresh.first.key, 'c:13');
    expect(fresh[2].key, 'c:11');
    expect(fresh.first.concept, 'ch1:c3');
    expect(fresh.first.cardKind, 'definition');
    expect(pool[FeedBucket.set]!.single.key, 's:set_1');
  });

  test('known, due, quick questions and the soft unlock', () async {
    await progress(11, 4, now.add(const Duration(days: 3)));
    await progress(12, 1, now.subtract(const Duration(hours: 1)));
    await progress(13, 2, now.add(const Duration(days: 1)));
    await db
        .into(db.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: const Value(1),
            completed: const Value(true),
          ),
        );
    final pool = await loader.load(now: now);
    expect(pool[FeedBucket.known]!.map((i) => i.key), ['c:11']);
    expect(pool[FeedBucket.due]!.map((i) => i.key), ['c:12']);
    // Lesson 1 is done: new cards come from lessons 2 and 3.
    expect(pool[FeedBucket.fresh]!.map((i) => i.lessonId).toSet(), {2, 3});
    expect(pool[FeedBucket.quick]!.map((i) => i.key), ['q:101']);
    final ahead = await loader.load(now: now, ahead: true);
    expect(ahead[FeedBucket.due]!.map((i) => i.key).toSet(), {'c:12', 'c:13'});
  });

  test('finished sets leave the feed; server sets parse from i18n', () async {
    final pool = await loader.load(now: now, finishedSets: {'set_1': true});
    expect(pool[FeedBucket.set], isEmpty);
    final source = (await CaseRepository(db).sources()).single;
    final set = CaseSet.fromSource(source.source, 'ar');
    expect(set.kind, CaseKind.mystery);
    expect(set.lessonId, 1);
    expect(set.title, 'Le cas');
    expect(set.commitIndex, 1);
    expect(set.slides[2].examNote, 'Tombe souvent');
  });

  test('card fields survive a language top-up of the lesson', () async {
    await BundleImporter(db).importLesson(7, {
      'id': 1,
      'i18n': {
        'ar': {'title': 'L1'},
      },
      'cards': [
        {
          'id': 11,
          'i18n': {
            'ar': {'front': 'f', 'back': 'b'},
          },
        },
      ],
      'questions': const [],
    }, merge: true);
    final row = await (db.select(
      db.keyValues,
    )..where((t) => t.name.equals('meta:1'))).getSingle();
    final meta = jsonDecode(row.value) as Map;
    expect((meta['c'] as Map)['11'], {
      'concept': 'ch1:c1',
      'difficulty': 3,
      'card_kind': 'formula',
    });
  });
}
