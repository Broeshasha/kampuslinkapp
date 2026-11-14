import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/local_data.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feed_repository_test.dart' show studyBundle;

/// B01 (A-01): a shared phone never shows or sends the previous student's work.
void main() {
  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    await BundleImporter(db).importBundle(studyBundle());
    outbox = OutboxRepository(db);
    for (var i = 0; i < 3; i++) {
      await outbox.enqueue('study_time', {'seconds': 60});
    }
  });

  tearDown(() => db.close());

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test(
    'another student signs in: the old work is wiped before any sync',
    () async {
      final prefs = await prefsWith({
        dataOwnerKey: 'uid-a',
        'ui_language': 'fr',
        'server_stats': '{"first_name":"Amine"}',
        'sb-proj-auth-token': 'session-b',
        'auth_last_uid': 'uid-b',
      });
      expect(await claimLocalData('uid-b', db, prefs), isTrue);
      expect(await outbox.due(), isEmpty);
      expect(await db.select(db.cards).get(), isEmpty);
      expect(prefs.getString('server_stats'), isNull);
      expect(prefs.getString(dataOwnerKey), 'uid-b');
      expect(prefs.getString('sb-proj-auth-token'), 'session-b');
      expect(prefs.getString('auth_last_uid'), 'uid-b');
      expect(prefs.getString('ui_language'), 'fr');
    },
  );

  test('the same student again: nothing is wiped', () async {
    final prefs = await prefsWith({dataOwnerKey: 'uid-a'});
    expect(await claimLocalData('uid-a', db, prefs), isFalse);
    expect(await outbox.due(), hasLength(3));
    expect(await db.select(db.cards).get(), isNotEmpty);
  });

  test('a phone updated from an older build keeps its data', () async {
    final prefs = await prefsWith({'server_stats': '{}'});
    expect(await claimLocalData('uid-a', db, prefs), isFalse);
    expect(await outbox.due(), hasLength(3));
    expect(prefs.getString(dataOwnerKey), 'uid-a');
    expect(prefs.getString('server_stats'), '{}');
  });

  test('two claims at once for the same student wipe only once', () async {
    final prefs = await prefsWith({dataOwnerKey: 'uid-a'});
    final results = await Future.wait([
      claimLocalData('uid-b', db, prefs),
      claimLocalData('uid-b', db, prefs),
    ]);
    expect(results, [true, true]);
    expect(prefs.getString(dataOwnerKey), 'uid-b');
  });
}
