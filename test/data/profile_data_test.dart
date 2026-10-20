import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:kampuslink/features/profile/account_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feed_repository_test.dart' show studyBundle;

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await BundleImporter(db).importBundle(studyBundle());
  });

  tearDown(() => db.close());

  test('saved cards list follows the bookmark', () async {
    final feed = FeedRepository(db, OutboxRepository(db));
    await feed.setSaved(1002, on: true);
    var saved = await feed.watchSaved().first;
    expect(saved.map((c) => c.card.id), [1002]);
    expect(saved.single.module.name, 'Chimie');
    await feed.setSaved(1002, on: false);
    saved = await feed.watchSaved().first;
    expect(saved, isEmpty);
  });

  test('account deletion wipes the phone but keeps device settings', () async {
    SharedPreferences.setMockInitialValues({
      'ui_language': 'ar',
      'theme_mode': 'dark',
      'reader_scale_step': 2,
      'last_synced_at': '2026-10-20',
      'server_stats': '{}',
      'onboarding_v1_done:abc': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await wipeLocalData(db, prefs);
    expect(await db.select(db.cards).get(), isEmpty);
    expect(await db.select(db.modules).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(prefs.getKeys(), {'ui_language', 'theme_mode', 'reader_scale_step'});
  });
}
