import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_seen.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test('B15: save + load round trip, one row per post', () async {
    final store = FeedSeenStore(db);
    final t = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    var seen = markShown(const {}, 'c:1', t);
    seen = markShown(seen, 'c:2', t);
    seen = markOutcome(seen, 'c:1', 'knew', t);
    await store.save(seen);
    final again = await FeedSeenStore(db).load();
    expect(again.keys.toSet(), {'c:1', 'c:2'});
    expect(again['c:1']!.outcome, 'knew');
    expect(again['c:1']!.last, t);
  });

  test('B15: prune keeps the newest posts only', () async {
    final store = FeedSeenStore(db);
    final seen = {
      for (var i = 0; i < FeedSeenStore.keep + 5; i++)
        'c:$i': markShown(const {}, 'x', DateTime(2026, 1, 1).add(Duration(minutes: i)))['x']!,
    };
    await store.save(seen);
    await store.prune();
    final rows = await db.select(db.feedSeenEntries).get();
    expect(rows.length, FeedSeenStore.keep);
    expect(rows.any((r) => r.postKey == 'c:0'), isFalse);
  });
}
