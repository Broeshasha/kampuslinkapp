import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/progress_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:kampuslink/data/sync/outbox_sync.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 19, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OutboxRepository outbox;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock();
    outbox = OutboxRepository(db, now: clock.call);
  });
  tearDown(() => db.close());

  test('reading_position keeps only the newest op per lesson', () async {
    await outbox.enqueue('reading_position', {
      'lesson_id': 1,
      'block_id': 'a',
    }, replaceKey: 'reading_position:1');
    await outbox.enqueue('reading_position', {
      'lesson_id': 1,
      'block_id': 'b',
    }, replaceKey: 'reading_position:1');
    await outbox.enqueue('review', {'card_id': 5, 'correct': true});
    final rows = await outbox.due();
    expect(rows, hasLength(2));
    expect(rows.first.kind, 'reading_position');
    expect(jsonDecode(rows.first.payloadJson)['block_id'], 'b');
  });

  test(
    'flush sends oldest first and clears applied/duplicate/rejected',
    () async {
      for (var i = 0; i < 3; i++) {
        await outbox.enqueue('review', {'card_id': i, 'correct': true});
      }
      List<Map<String, Object?>>? sent;
      final sync = OutboxSync(outbox, (ops) async {
        sent = ops;
        return [
          {'op_id': ops[0]['op_id'], 'status': 'applied'},
          {'op_id': ops[1]['op_id'], 'status': 'duplicate'},
          {
            'op_id': ops[2]['op_id'],
            'status': 'rejected',
            'message': 'card_not_available',
          },
        ];
      });
      final result = await sync.flush();
      expect(result.ok, isTrue);
      expect(result.sent, 3);
      expect((sent!.first['payload'] as Map)['card_id'], 0);
      expect(await outbox.due(), isEmpty);
    },
  );

  test('a network error keeps every op and backs off: nothing lost', () async {
    await outbox.enqueue('study_time', {'seconds': 60});
    final sync = OutboxSync(
      outbox,
      (ops) async => throw TimeoutException('no network'),
    );
    final result = await sync.flush();
    expect(result.failure, isA<OfflineFailure>());
    expect(await outbox.due(), isEmpty);
    clock.advance(const Duration(seconds: 6));
    final rows = await outbox.due();
    expect(rows, hasLength(1));
    expect(rows.single.attempts, 1);
  });

  test('ops the server did not answer are retried later', () async {
    await outbox.enqueue('review', {'card_id': 1, 'correct': false});
    final sync = OutboxSync(outbox, (ops) async => <dynamic>[]);
    final result = await sync.flush();
    expect(result.sent, 0);
    expect(await outbox.due(), isEmpty);
    clock.advance(const Duration(seconds: 6));
    expect(await outbox.due(), hasLength(1));
  });

  test('a review updates the card locally and queues one op', () async {
    final progress = ProgressRepository(db, outbox, now: clock.call);
    await progress.reviewCard(9, correct: true);
    final p = await (db.select(
      db.cardProgress,
    )..where((t) => t.cardId.equals(9))).getSingle();
    expect(p.box, 2);
    expect(p.dueAt, clock.now.add(const Duration(days: 1)));
    final ops = await outbox.due();
    expect(ops.single.kind, 'review');
  });

  test('study time adds up per day and queues ops', () async {
    final progress = ProgressRepository(db, outbox, now: clock.call);
    await progress.logStudySeconds(60);
    await progress.logStudySeconds(1200);
    final day = await db.select(db.studyDays).getSingle();
    expect(day.seconds, 960);
    expect(await outbox.due(), hasLength(2));
  });
}
