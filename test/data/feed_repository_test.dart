import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_repository.dart';
import 'package:kampuslink/data/learning/progress_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';

/// Module 7: lesson 21 with cards 1001-1003 and questions 3001-3003
/// (correct answer = option 1).
Map<String, dynamic> studyBundle() => {
  'schema_version': 2,
  'module': {'id': 7, 'name': 'Chimie', 'semester': 3},
  'version': 1,
  'languages': ['fr', 'ar'],
  'lessons': [
    {
      'id': 21,
      'position': 1,
      'source_lang': 'fr',
      'i18n': {
        'fr': {'title': 'Les oxydes', 'blocks': <Object?>[]},
      },
      'cards': [
        for (var i = 1; i <= 3; i++)
          {
            'id': 1000 + i,
            'position': i,
            'i18n': {
              'fr': {'front': 'Q$i', 'back': 'R$i'},
              'ar': {'front': 'AQ$i', 'back': 'AR$i'},
            },
          },
      ],
      'questions': [
        for (var i = 1; i <= 3; i++)
          {
            'id': 3000 + i,
            'kind': 'mcq',
            'correct_index': 1,
            'position': i,
            'i18n': {
              'fr': {
                'prompt': 'Question $i',
                'options': ['a', 'b', 'c'],
                'explanation': 'parce que',
              },
            },
          },
      ],
    },
  ],
  'resources': <Object?>[],
  'glossary': <Object?>[],
};

void main() {
  late AppDatabase db;
  late FeedRepository feed;
  late ProgressRepository progress;
  final t0 = DateTime(2026, 10, 20, 9);
  var now = t0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = t0;
    final outbox = OutboxRepository(db, now: () => now);
    feed = FeedRepository(db, outbox, now: () => now);
    progress = ProgressRepository(db, outbox, now: () => now);
    await BundleImporter(db).importBundle(studyBundle());
  });

  tearDown(() => db.close());

  test('feed: due cards first, then new ones; not-due cards wait', () async {
    await progress.reviewCard(1001, correct: true); // box 2: due in 1 day
    await progress.reviewCard(1002, correct: false); // box 1: due in 10 min
    now = t0.add(const Duration(minutes: 20));
    final cards = await feed.feed();
    expect(cards.map((c) => c.card.id), [1002, 1003]);
    final ahead = await feed.feed(ahead: true);
    expect(ahead.map((c) => c.card.id), [1001]);
    expect(await feed.nextDueAt(), t0.add(const Duration(days: 1)));
  });

  test('card text follows the language, French as fallback', () async {
    final card = (await feed.feed()).first;
    expect(card.text('ar').front, 'AQ1');
    expect(card.text('en').front, 'Q1');
    expect(card.text('en').language, 'fr');
  });

  test('like / save keep the Leitner box and queue one op each', () async {
    await progress.reviewCard(1003, correct: true);
    await feed.setLiked(1003, on: true);
    await feed.setLiked(1003, on: false);
    await feed.setSaved(1003, on: true);
    final row = await (db.select(
      db.cardProgress,
    )..where((t) => t.cardId.equals(1003))).getSingle();
    expect(row.box, 2);
    expect(row.liked, false);
    expect(row.saved, true);
    final kinds = (await db.select(db.outbox).get()).map((o) => o.kind);
    expect(kinds.where((k) => k == 'like').length, 1);
    expect(kinds.where((k) => k == 'save').length, 1);
  });

  test('streak counts days with 5+ minutes, ending today or yesterday', () {
    final today = DateTime(2026, 10, 20);
    expect(
      localStreak({
        '2026-10-20': 400,
        '2026-10-19': 300,
        '2026-10-18': 900,
        '2026-10-16': 900,
      }, today),
      3,
    );
    expect(localStreak({'2026-10-19': 600, '2026-10-18': 600}, today), 2);
    expect(localStreak({'2026-10-20': 100}, today), 0);
  });
}
