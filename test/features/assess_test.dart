import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/data/assess/assess_models.dart';
import 'package:kampuslink/data/assess/assess_store.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';
import 'package:kampuslink/features/assess/exam_pages.dart';
import 'package:kampuslink/features/assess/practice_pages.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ondes 840 (canonical shape).
Map<String, dynamic> wavesPaper() => {
  'id': 17,
  'module_id': 840,
  'ref': 'mock_01',
  'position': 1,
  'schema': 'kl-exams-1.0',
  'duration_min': 120,
  'total_points': 20.0,
  'title': {'en': 'Mock exam 1', 'fr': 'Examen blanc 1'},
  'instructions': const {},
  'exercises': [
    {
      'id': 'ex1',
      'points': 6,
      'concepts': ['chapter_01:c_period'],
      'title': {'fr': 'Pendule', 'en': 'Pendulum'},
      'statement': {'en': r'A pendulum of length \(L = 1\) m.'},
      'parts': [
        {
          'id': 'a',
          'points': 1.5,
          'prompt': {'en': 'Give the period.'},
          'solution_steps': [
            {'en': r'Use \(T = 2\pi\sqrt{L/g}\).'},
            {'en': 'Replace the values.'},
          ],
          'final_answer': {'en': 'T = 2.0 s'},
          'marking': [
            {
              'points': 0.5,
              'criterion': {'en': 'Formula'},
            },
            {
              'points': null,
              'criterion': {'en': 'Unit given'},
            },
          ],
        },
        {
          'id': 'b',
          'points': 4.5,
          'prompt': {'en': 'Find the frequency.'},
          'solution_steps': const [],
          'final_answer': {'en': 'f = 0.5 Hz'},
          'marking': const [],
        },
      ],
    },
    {
      'id': 'ex2',
      'points': 14,
      'parts': [
        {
          'id': 'a',
          'points': 14,
          'prompt': 'Plain string prompt.',
          'solution_steps': {
            'en': ['Step one', 'Step two'],
          },
          'final_answer': 'Done',
          'marking': const [],
        },
      ],
    },
  ],
};

/// Chimie 842 (converted: questions/sections copies, text marking lines).
Map<String, dynamic> chemistryPaper() => {
  'id': 21,
  'module_id': 842,
  'duration_min': 90,
  'total_points': 10,
  'title': 'Sujet 1',
  'exercises': [
    {
      'id': 'ex1',
      'points': 10,
      'questions': [
        {'id': 'zzz', 'prompt': 'ignored'},
      ],
      'sections': [
        {'id': 'yyy'},
      ],
      'parts': [
        {
          'id': 'a',
          'points': 10,
          'question': {'fr': 'Equilibrer la reaction.'},
          'steps': ['Compter les atomes'],
          'answer': {'fr': 'Fe + O2'},
          'marking': ['Bonne formule : 5 pts', 'Bilan : 5 pts'],
          'chapters': ['x'],
        },
      ],
    },
  ],
};

/// Python 994 practice with code solutions.
Map<String, dynamic> pythonPractice() => {
  'id': 301,
  'ref': 'chapter_02/p_01',
  'chapter_ref': 'chapter_02',
  'unit_number': 2,
  'position': 201,
  'difficulty': 2,
  'title': {'en': 'Loops'},
  'statement': {'en': 'Write a loop.'},
  'parts': [
    {
      'id': 'a',
      'prompt': {'en': 'Print 0 to 2.'},
      'hints': [
        {'en': 'Use range.'},
        {'en': 'range(3)'},
      ],
      'solution_steps': [
        {'en': 'Loop over range(3).'},
      ],
      'final_answer': {'en': '0 1 2'},
      'solution_code': 'for i in range(3):\n    print(i)',
      'solution_output': '0\n1\n2',
    },
  ],
};

void main() {
  late AppDatabase db;
  late AssessStore store;
  final now = DateTime(2026, 10, 24, 10);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = AssessStore(
      db,
      OutboxRepository(db, now: () => now),
      now: () => now,
    );
  });
  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> ops(String kind) async => [
    for (final r in await db.select(db.outbox).get())
      if (r.kind == kind)
        (jsonDecode(r.payloadJson) as Map).cast<String, dynamic>(),
  ];

  test('every real paper variant parses; old copies are ignored', () {
    final w = ExamPaper.fromMap(wavesPaper(), 'ar');
    expect(w.title, 'Examen blanc 1');
    expect(w.exercises.first.title, 'Pendule');
    expect(w.exercises.first.parts.first.steps.length, 2);
    expect(w.exercises.first.parts.first.marking.last.points, isNull);
    expect(w.exercises[1].parts.first.prompt, 'Plain string prompt.');
    expect(w.exercises[1].parts.first.steps, ['Step one', 'Step two']);
    expect(w.maxByKey, {'ex1/a': 1.5, 'ex1/b': 4.5, 'ex2/a': 14.0});
    final c = ExamPaper.fromMap(chemistryPaper(), 'fr');
    expect(c.exercises.single.parts.single.id, 'a');
    expect(c.exercises.single.parts.single.prompt, 'Equilibrer la reaction.');
    expect(c.exercises.single.parts.single.answer, 'Fe + O2');
    expect(c.exercises.single.parts.single.marking.map((m) => m.criterion), [
      'Bonne formule : 5 pts',
      'Bilan : 5 pts',
    ]);
    final p = PracticeItem.fromMap(pythonPractice(), 'fr');
    expect(p.parts.single.hints.length, 2);
    expect(p.parts.single.code?.output, '0\n1\n2');
    expect(pickTextList({'en': 'one'}, 'en'), ['one']);
  });

  test('scores: 0.25 grid, clamped, unknown keys dropped, out of 20', () {
    expect(clampPoints(1.3, 1.5), 1.25);
    expect(clampPoints(9, 1.5), 1.5);
    expect(clampPoints(-1, 1.5), 0);
    final max = ExamPaper.fromMap(wavesPaper(), 'en').maxByKey;
    final total = attemptTotal({'ex1/a': 1.5, 'ex2/a': 7, 'zz/q': 3}, max);
    expect(total, 8.5);
    expect(score20(8.5, 20), 8.5);
    expect(score20(5, 10), 10);
    expect(formatPoints(12.5), '12.5');
    expect(formatPoints(7), '7');
    expect(formatPoints(0.25), '0.25');
  });

  test(
    'attempts: whole scores map every time; finished never goes back',
    () async {
      final a = ExamAttempt(
        attemptId: 'u1',
        paperId: 17,
        status: AttemptStatus.inProgress,
        startedAt: now,
        at: now,
      );
      await store.saveAttempt(a);
      await store.saveAttempt(
        a.copyWith(
          status: AttemptStatus.finished,
          finishedAt: now,
          at: now.add(const Duration(minutes: 1)),
          scores: {'ex1/a': 1},
        ),
      );
      await store.saveAttempt(
        a.copyWith(
          status: AttemptStatus.finished,
          at: now.add(const Duration(minutes: 2)),
          scores: {'ex1/a': 1, 'ex1/b': 2},
        ),
      );
      final sent = await ops('exam_attempt');
      expect(sent, hasLength(1), reason: 'one unsent op per attempt');
      expect(sent.single['scores'], {'ex1/a': 1.0, 'ex1/b': 2.0});
      expect(sent.single['status'], 'finished');
      // An older server row cannot bring it back to in_progress.
      await store.mergeServerAttempts([
        {
          'attempt_id': 'u1',
          'paper_id': 17,
          'status': 'in_progress',
          'started_at': now.toIso8601String(),
          'updated_at': now.add(const Duration(minutes: 9)).toIso8601String(),
          'scores': const {},
        },
      ]);
      final list = await store.attempts(17);
      expect(list.single.status, AttemptStatus.finished);
      final paper = ExamPaper.fromMap(wavesPaper(), 'en');
      expect(bestScore20(list, paper), 0);
    },
  );

  test(
    'practice progress: max hints, sticky solution, latest rating',
    () async {
      await store.savePracticeProgress(301, hintsSeen: 2);
      await store.savePracticeProgress(301, hintsSeen: 1, solutionSeen: true);
      await store.savePracticeProgress(301, rating: 'partly');
      final p = await store.practiceProgress(301);
      expect(p['hints_seen'], 2);
      expect(p['solution_seen'], isTrue);
      expect(p['self_rating'], 'partly');
      final sent = await ops('practice_progress');
      expect(sent.single['practice_id'], 301);
      expect(sent.single['self_rating'], 'partly');
    },
  );

  test('manifest: new or changed rev downloads, removed ones go', () async {
    var practiceCalls = 0;
    var paperCalls = 0;
    Future<void> apply(Map<String, dynamic> manifest) => store.applyManifest(
      840,
      manifest,
      fetchPractice: (ref) async {
        practiceCalls++;
        return [pythonPractice()];
      },
      fetchPaper: (id) async {
        paperCalls++;
        return wavesPaper();
      },
    );
    await apply({
      'practice': [
        {
          'chapter_ref': 'chapter_02',
          'unit_number': 2,
          'count': 1,
          'rev': 'r1',
        },
      ],
      'exams': [
        {'id': 17, 'rev': 'e1', 'title': 'T', 'duration_min': 120},
      ],
    });
    await apply({
      'practice': [
        {
          'chapter_ref': 'chapter_02',
          'unit_number': 2,
          'count': 1,
          'rev': 'r1',
        },
      ],
      'exams': [
        {'id': 17, 'rev': 'e2', 'title': 'T', 'duration_min': 120},
      ],
    });
    expect(practiceCalls, 1);
    expect(paperCalls, 2);
    await apply(const {'practice': [], 'exams': []});
    expect(await store.practiceChapter(840, 'chapter_02'), isEmpty);
    expect(await store.examPaper(17), isNull);
    expect(await store.examIndex(840), isEmpty);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> seedExam() async {
    await store.applyManifest(
      840,
      {
        'practice': const [],
        'exams': [
          {'id': 17, 'rev': 'e1', 'title': 'T', 'duration_min': 120},
        ],
      },
      fetchPractice: (_) async => const [],
      fetchPaper: (_) async => wavesPaper(),
    );
    await store.saveAttempt(
      ExamAttempt(
        attemptId: 'u1',
        paperId: 17,
        status: AttemptStatus.inProgress,
        startedAt: now,
        at: now,
      ),
    );
  }

  testWidgets('exam mode hides solutions; correction scores in 0.25 steps', (
    tester,
  ) async {
    await seedExam();
    await pump(
      tester,
      ExamPage(
        paperId: 17,
        attemptId: 'u1',
        now: () => now.add(const Duration(minutes: 5)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Give the period.'), findsOneWidget);
    expect(find.text('T = 2.0 s'), findsNothing);
    expect(find.text('Marking scheme'), findsNothing);
    expect(find.text('1:55:00'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('T = 2.0 s'), findsOneWidget);
    expect(find.text('Marking scheme'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('plus-ex1/a')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('0.25 / 1.5'), findsOneWidget);
    final sent = await ops('exam_attempt');
    expect(sent.single['status'], 'finished');
    expect(sent.single['scores'], {'ex1/a': 0.25});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('exam correction fits 320 wide at 1.5x in Arabic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedExam();
    await store.saveAttempt(
      ExamAttempt(
        attemptId: 'u1',
        paperId: 17,
        status: AttemptStatus.finished,
        startedAt: now,
        finishedAt: now,
        at: now.add(const Duration(minutes: 1)),
      ),
    );
    await pump(
      tester,
      const ExamPage(paperId: 17, attemptId: 'u1'),
      locale: const Locale('ar'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('practice: hints one at a time, solution, then the rating', (
    tester,
  ) async {
    await store.applyManifest(
      994,
      {
        'practice': [
          {
            'chapter_ref': 'chapter_02',
            'unit_number': 2,
            'count': 1,
            'rev': 'r',
          },
        ],
        'exams': const [],
      },
      fetchPractice: (_) async => [pythonPractice()],
      fetchPaper: (_) async => const {},
    );
    await pump(
      tester,
      const PracticeItemPage(
        moduleId: 994,
        chapterRef: 'chapter_02',
        practiceId: 301,
      ),
    );
    expect(find.text('Write a loop.'), findsOneWidget);
    expect(find.text('Use range.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hint-a')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Use range.'), findsOneWidget);
    expect(find.text('range(3)'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hint-a')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('range(3)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('solve-a')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0 1 2'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('rate-got_it')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('rate-got_it')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final p = await store.practiceProgress(301);
    expect(p['hints_seen'], 2);
    expect(p['solution_seen'], isTrue);
    expect(p['self_rating'], 'got_it');
  });
}
