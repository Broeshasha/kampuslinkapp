import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/cases/case_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_pool.dart';
import 'package:kampuslink/data/learning/feed_queue.dart';
import 'package:kampuslink/data/learning/feed_repository.dart';
import 'package:kampuslink/data/profile/study_level.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:kampuslink/features/preview/preview_page.dart';
import 'package:kampuslink/features/profile/semester_sheet.dart';

import '../helpers/pump_in_app.dart';

ModuleRow module(int id, int? semester) => ModuleRow(
  id: id,
  name: 'M$id',
  semester: semester,
  serverVersion: 1,
  localVersion: 1,
  lessonCount: 0,
  lessonsDone: 0,
  resourceCount: 0,
  languages: 'fr',
);

/// One module: 2 lessons x 2 cards, one MCQ per lesson, one carousel set.
Map<String, dynamic> bundle(int moduleId, int semester) {
  final base = moduleId * 100;
  return {
    'schema_version': 3,
    'module': {'id': moduleId, 'name': 'M$moduleId', 'semester': semester},
    'version': 1,
    'languages': ['fr'],
    'lessons': [
      for (var l = 1; l <= 2; l++)
        {
          'id': base + l,
          'position': l,
          'i18n': {
            'fr': {'title': 'L$l'},
          },
          'cards': [
            for (var c = 1; c <= 2; c++)
              {
                'id': base + l * 10 + c,
                'position': c,
                'concept': 'm$moduleId:l$l:c$c',
                'i18n': {
                  'fr': {'front': 'f', 'back': 'b'},
                },
              },
          ],
          'questions': [
            {
              'id': base + 50 + l,
              'kind': 'mcq',
              'correct_index': 0,
              'position': 1,
              'concept': 'm$moduleId:l$l:c1',
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
    'sets': [
      {
        'id': 'set_$moduleId',
        'kind': 'mystery',
        'position': 1,
        'lesson_id': base + 1,
        'i18n': {
          'fr': {
            'title': 'Cas',
            'slides': [
              {'id': 'a', 'role': 'hook', 'title': 'Pourquoi ?'},
            ],
          },
        },
      },
    ],
  };
}

class _Fixed extends StudyLevelController {
  _Fixed(this.level);

  final StudyLevel level;

  @override
  StudyLevel build() => level;
}

void main() {
  test('only current-semester modules; none without a semester', () {
    final all = [module(1, 3), module(2, 4), module(3, null), module(4, 3)];
    expect(visibleModules(all, 3).map((m) => m.id), [1, 4]);
    expect(visibleModules(all, 4).map((m) => m.id), [2]);
    expect(visibleModules(all, null).map((m) => m.id), [1, 2, 4]);
    expect(inSemester(null, 3), isFalse);
    expect(yearSemesters['L2'], [3, 4]);
    expect(yearSemesters['M1'], [1, 2]);
  });

  test('banner dates: Jan 15 - Mar 15 and Jun 15 - Oct 15, 14-day dismiss', () {
    bool due(int m, int d) => semesterBannerDue(DateTime(2026, m, d, 12));
    expect(
      [due(1, 14), due(1, 15), due(3, 15), due(3, 16)],
      [false, true, true, false],
    );
    expect(
      [due(6, 14), due(6, 15), due(10, 15), due(10, 16)],
      [false, true, true, false],
    );
    final now = DateTime(2026, 2, 1);
    expect(
      semesterBannerDue(now, hiddenUntil: now.add(const Duration(days: 3))),
      isFalse,
    );
    expect(
      semesterBannerDue(
        now,
        hiddenUntil: now.subtract(const Duration(days: 1)),
      ),
      isTrue,
    );
  });

  test('draft preview: ids missing from the student copy are drafts', () {
    expect(draftIds([1, 2, 3], [1, 3]), {'2'});
    expect(draftIds(['s1', 's2'], const []), {'s1', 's2'});
  });

  group('feed with S3 and S4 content downloaded', () {
    late AppDatabase db;
    late FeedPoolLoader loader;
    final now = DateTime(2026, 10, 21, 12);

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      final outbox = OutboxRepository(db, now: () => now);
      loader = FeedPoolLoader(
        db,
        FeedRepository(db, outbox, now: () => now),
        CaseRepository(db, outbox),
      );
      await BundleImporter(db).importBundle(bundle(7, 3));
      await BundleImporter(db).importBundle(bundle(8, 4));
      // Some history in both modules: known, due and a done lesson.
      for (final (card, box) in [(711, 4), (712, 1), (811, 4), (812, 1)]) {
        await db
            .into(db.cardProgress)
            .insertOnConflictUpdate(
              CardProgressCompanion(
                cardId: Value(card),
                box: Value(box),
                dueAt: Value(now.subtract(const Duration(hours: 1))),
                lastReviewedAt: Value(now.subtract(const Duration(days: 2))),
              ),
            );
      }
      for (final lesson in [701, 801]) {
        await db
            .into(db.lessonProgress)
            .insert(
              LessonProgressCompanion.insert(
                lessonId: Value(lesson),
                completed: const Value(true),
              ),
            );
      }
    });
    tearDown(() => db.close());

    Set<int> modulesIn(Map<FeedBucket, List<FeedItem>> pool) => {
      for (final items in pool.values)
        for (final i in items)
          switch (i.payload) {
            final FeedCard c => c.module.id,
            final FeedQuestion q => q.module.id,
            final CaseSource s => s.moduleId ?? -1,
            _ => -1,
          },
    };

    test('S3 student: no S4 item in any bucket', () async {
      final pool = await loader.load(now: now, semester: 3);
      expect(modulesIn(pool), {7});
      for (final b in FeedBucket.values) {
        expect(pool[b], isNotEmpty, reason: '$b should have S3 items');
      }
    });

    test('switch to S4: only S4', () async {
      final pool = await loader.load(now: now, semester: 4);
      expect(modulesIn(pool), {8});
    });
  });

  test('Modules list follows the semester (S3 -> S4)', () async {
    for (final (semester, ids) in [
      (3, {7}),
      (4, {8}),
    ]) {
      final container = ProviderContainer(
        overrides: [
          modulesStreamProvider.overrideWith(
            (ref) =>
                Stream.value([module(7, 3), module(8, 4), module(9, null)]),
          ),
          studyLevelProvider.overrideWith(
            () => _Fixed(StudyLevel(year: 'L2', semester: semester)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(visibleModulesProvider, (_, _) {});
      await container.read(modulesStreamProvider.future);
      expect(container.read(visibleModuleIdsProvider), ids);
    }
  });

  for (final (lang, file) in [
    ('en', 'goldens/semester_banner_en_320.png'),
    ('ar', 'goldens/semester_banner_ar_320.png'),
  ]) {
    testWidgets('golden: semester banner ($lang, 320)', (tester) async {
      tester.view.physicalSize = const Size(320, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = 0;
      await pumpInApp(
        tester,
        Padding(
          padding: const EdgeInsets.all(12),
          child: RepaintBoundary(
            key: const ValueKey('golden'),
            child: SemesterBannerCard(
              onChange: () => opened++,
              onDismiss: () {},
            ),
          ),
        ),
        locale: Locale(lang),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile(file),
      );
      await tester.tap(find.byType(SemesterBannerCard));
      expect(opened, 1);
    });
  }
}
