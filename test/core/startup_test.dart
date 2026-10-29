import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/app/app.dart';
import 'package:kampuslink/core/auth/auth_controller.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/core/supabase/supabase_bootstrap.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/cases/case_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_queue.dart';
import 'package:kampuslink/data/learning/feed_repository.dart';
import 'package:kampuslink/data/learning/feed_snapshot.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/features/home/home_page.dart';
import 'package:kampuslink/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Module 7 (semester 3): one lesson, two cards, one quick question.
Map<String, dynamic> _bundle() => {
  'schema_version': 3,
  'module': {'id': 7, 'name': 'Stats', 'semester': 3},
  'version': 1,
  'languages': ['fr'],
  'lessons': [
    {
      'id': 1,
      'position': 1,
      'i18n': {
        'fr': {'title': 'L1'},
      },
      'cards': [
        for (var c = 1; c <= 2; c++)
          {
            'id': 10 + c,
            'position': c,
            'i18n': {
              'fr': {'front': 'f$c', 'back': 'b$c'},
            },
          },
      ],
      'questions': [
        {
          'id': 101,
          'kind': 'mcq',
          'correct_index': 0,
          'position': 1,
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
  'sets': const [],
};

void main() {
  test('feed snapshot: the same posts come back in order, only once', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await BundleImporter(db).importBundle(_bundle());
    final store = FeedSnapshotStore(db, CaseRepository(db));
    await store.save(const [
      FeedItem(key: 'c:12', bucket: FeedBucket.due),
      FeedItem(key: 'q:101', bucket: FeedBucket.quick),
      FeedItem(key: 'c:11', bucket: FeedBucket.fresh),
      FeedItem(key: 'c:999', bucket: FeedBucket.known),
    ], semester: 3);
    final back = await store.restore(semester: 3);
    expect(back.map((i) => i.key), ['c:12', 'q:101', 'c:11']);
    expect(back.first.payload, isA<FeedCard>());
    expect(back.first.bucket, FeedBucket.due);
    expect(await store.restore(semester: 3), isEmpty);
    await store.save(const [
      FeedItem(key: 'c:11', bucket: FeedBucket.fresh),
    ], semester: 3);
    expect(await store.restore(semester: 4), isEmpty);
  });

  testWidgets(
    'Supabase still starting (slow network): Home on the first frame',
    (tester) async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      SharedPreferences.setMockInitialValues({
        lastUserIdKey: 'u1',
        'onboarding_v1_done:u1': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      container.read(backendStartingProvider.notifier).set(true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KampusLinkApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
    },
  );
}
