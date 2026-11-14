// B15: every schema version must upgrade old phones without losing data.
// The schema snapshots live in drift_schemas/ and the helpers in
// test/generated_migrations/ (both made by the founder's PowerShell block:
// drift_dev schema dump + schema generate).
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/db/app_database.dart';

import '../generated_migrations/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 -> v2: schema is right and feed_seen moves into rows', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO key_values (name, value) VALUES ('feed_seen', "
      "'{\"c:1\":[1700000000000,3,1,\"knew\"],\"c:2\":[1700000001000,1,1]}')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO key_values (name, value) VALUES ('keep_me', 'yes')",
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final rows = await db.select(db.feedSeenEntries).get();
    expect(rows.map((r) => r.postKey).toSet(), {'c:1', 'c:2'});
    expect(rows.firstWhere((r) => r.postKey == 'c:1').outcome, 'knew');
    final kv = await db.select(db.keyValues).get();
    expect(kv.map((r) => r.name), ['keep_me']);
    await db.close();
  });

  test('v1 -> v2 with a broken feed_seen value still opens', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO key_values (name, value) VALUES ('feed_seen', 'not json')",
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    expect(await db.select(db.feedSeenEntries).get(), isEmpty);
    await db.close();
  });
}
