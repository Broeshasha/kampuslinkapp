import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/reports/content_reports.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';

void main() {
  late AppDatabase db;
  late ContentReports reports;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    reports = ContentReports(OutboxRepository(db));
  });
  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> ops() async => [
    for (final r in await db.select(db.outbox).get())
      if (r.kind == 'content_report')
        (jsonDecode(r.payloadJson) as Map).cast<String, dynamic>(),
  ];

  test('a report is one outbox op in the contract 11 shape', () async {
    await reports.report(
      targetType: 'card',
      targetId: '42',
      lessonId: 7,
      reason: 'typo',
      note: '  le mot est mal ecrit  ',
    );
    expect(await ops(), [
      {
        'target_type': 'card',
        'target_id': '42',
        'lesson_id': 7,
        'reason': 'typo',
        'note': 'le mot est mal ecrit',
      },
    ]);
  });

  test('reporting the same target again replaces the unsent report', () async {
    await reports.report(targetType: 'set', targetId: 's1', reason: 'typo');
    await reports.report(
      targetType: 'set',
      targetId: 's1',
      reason: 'unclear',
      note: 'x' * 500,
    );
    final list = await ops();
    expect(list, hasLength(1));
    expect(list.single['reason'], 'unclear');
    expect((list.single['note'] as String).length, 300);
    expect(list.single.containsKey('lesson_id'), isFalse);
  });

  test('a block report needs its lesson; unknown values are refused', () {
    expect(
      () => reports.report(targetType: 'block', targetId: 'b1', reason: 'typo'),
      throwsArgumentError,
    );
    expect(
      () => reports.report(
        targetType: 'learn_set',
        targetId: '1',
        reason: 'typo',
      ),
      throwsArgumentError,
    );
    expect(
      () => reports.report(targetType: 'card', targetId: '1', reason: 'spam'),
      throwsArgumentError,
    );
  });
}
