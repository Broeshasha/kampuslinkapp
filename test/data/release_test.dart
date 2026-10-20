import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/config/app_config.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/data/chat/chat_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';

void main() {
  test('please-update gate: only a known build below the minimum', () {
    expect(needsUpdate(5, 6), isTrue);
    expect(needsUpdate(6, 6), isFalse);
    expect(needsUpdate(5, 0), isFalse);
    expect(needsUpdate(null, 9), isFalse, reason: 'unknown build never blocks');
  });

  test('background sync finds the modules with unsent chat messages', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ChatRepository(
      db,
      fetch: (m, b) async => throw const OfflineFailure(),
      post: (m, body, lang, id) async => throw const OfflineFailure(),
    );
    expect(await repo.modulesWithPending(), isEmpty);
    await repo.queue(7, 'one');
    await repo.queue(12, 'two');
    expect((await repo.modulesWithPending())..sort(), [7, 12]);
  });
}
