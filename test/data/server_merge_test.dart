import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/progress_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:kampuslink/data/sync/server_merge.dart';

import 'feed_repository_test.dart' show studyBundle;

/// Server rows as Supabase returns them (ISO timestamps in UTC).
ServerProgress serverRows({
  DateTime? reviewedAt,
  DateTime? readAt,
  String block = 'b9',
}) => ServerProgress(
  cards: [
    {
      'card_id': 1001,
      'box': 4,
      'due_at': DateTime.utc(2026, 10, 27, 8).toIso8601String(),
      'last_reviewed_at': (reviewedAt ?? DateTime.utc(2026, 10, 20, 8))
          .toIso8601String(),
    },
  ],
  lessons: [
    {'lesson_id': 21, 'score': 80},
  ],
  positions: [
    {
      'lesson_id': 21,
      'block_id': block,
      'progress': 0.6,
      'updated_at': (readAt ?? DateTime.utc(2026, 10, 20, 8)).toIso8601String(),
    },
  ],
  likes: {1002},
  saves: {1003},
);

void main() {
  late AppDatabase db;
  late ProgressRepository progress;
  late ServerMerge merge;
  var now = DateTime.utc(2026, 10, 20, 9).toLocal();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 20, 9).toLocal();
    final outbox = OutboxRepository(db, now: () => now);
    progress = ProgressRepository(db, outbox, now: () => now);
    merge = ServerMerge(db, now: () => now);
    await BundleImporter(db).importBundle(studyBundle());
  });

  tearDown(() => db.close());

  Future<CardProgressRow?> card(int id) => (db.select(
    db.cardProgress,
  )..where((t) => t.cardId.equals(id))).getSingleOrNull();

  Future<ReadingPositionRow?> position(int lessonId) => (db.select(
    db.readingPositions,
  )..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull();

  test('reinstall: an empty phone gets everything back', () async {
    final report = await merge.merge(serverRows());
    expect(report.cards, 1);
    expect((await card(1001))!.box, 4);
    final done = await (db.select(db.lessonProgress)).getSingle();
    expect(done.completed, isTrue);
    expect(done.score, 80);
    expect((await position(21))!.blockId, 'b9');
    expect((await card(1002))!.liked, isTrue);
    expect((await card(1003))!.saved, isTrue);
  });

  test('second device: the newest side wins, done stays done', () async {
    // This phone reviewed card 1001 at 09:00; the server row is from 08:00.
    await progress.reviewCard(1001, correct: false);
    await progress.saveReadingPosition(21, 'b2', 0.2);
    await progress.completeLesson(21, score: 95);
    await db.delete(db.outbox).go(); // everything was already sent
    await merge.merge(serverRows());
    expect((await card(1001))!.box, 1, reason: 'local review is newer');
    expect((await position(21))!.blockId, 'b2', reason: 'local is newer');
    final done = await (db.select(db.lessonProgress)).getSingle();
    expect(done.score, 95, reason: 'best score is kept');

    // Later the other device reads further and reviews again.
    await merge.merge(
      serverRows(
        reviewedAt: DateTime.utc(2026, 10, 20, 10),
        readAt: DateTime.utc(2026, 10, 20, 10),
        block: 'b7',
      ),
    );
    expect((await card(1001))!.box, 4);
    expect((await position(21))!.blockId, 'b7');
  });

  test('conflict: a row with an unsent op is never overwritten', () async {
    await progress.reviewCard(1001, correct: false);
    await progress.saveReadingPosition(21, 'b2', 0.2);
    final report = await merge.merge(
      serverRows(
        reviewedAt: DateTime.utc(2026, 10, 20, 11),
        readAt: DateTime.utc(2026, 10, 20, 11),
      ),
    );
    expect(report.keptLocal, 2);
    expect((await card(1001))!.box, 1);
    expect((await position(21))!.blockId, 'b2');
  });

  test('likes and saves follow the server unless a toggle is unsent', () async {
    await db
        .into(db.cardProgress)
        .insert(
          CardProgressCompanion.insert(
            cardId: const Value(1003),
            liked: const Value(true),
          ),
        );
    await merge.merge(serverRows());
    final c = await card(1003);
    expect(c!.liked, isFalse, reason: 'server has no like for 1003');
    expect(c.saved, isTrue);
  });
}
