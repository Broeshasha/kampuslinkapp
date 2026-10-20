import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/progress_repository.dart';
import 'package:kampuslink/data/lessons/lesson_content.dart';
import 'package:kampuslink/data/lessons/lesson_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';

Map<String, dynamic> lesson(int id, int position, {int unit = 1}) => {
  'id': id,
  'position': position,
  'source_lang': 'fr',
  'unit': {
    'ref': 'ch$unit',
    'number': unit,
    'title': {'fr': 'Chapitre $unit', 'en': 'Chapter $unit'},
  },
  'estimated_minutes': 8,
  'i18n': {
    'fr': {
      'title': 'Lecon $id',
      'blocks': [
        {'id': 'b1', 'type': 'paragraph', 'content': 'fr'},
      ],
    },
    'ar': {
      'title': 'AR $id',
      'blocks': [
        {'id': 'b1', 'type': 'paragraph', 'content': 'ar'},
      ],
    },
  },
};

Map<String, dynamic> moduleBundle() => {
  'schema_version': 2,
  'module': {'id': 7, 'name': 'Chimie', 'semester': 3},
  'version': 1,
  'languages': ['fr', 'ar'],
  'lessons': [lesson(12, 2), lesson(11, 1), lesson(13, 3, unit: 2)],
  'resources': [
    {
      'id': 1,
      'type': 'td',
      'format': 'pdf',
      'title': 'TD 1',
      'file_urls': ['https://files.kampus-link.com/a.pdf'],
      'size_bytes': 2048,
    },
  ],
  'glossary': <Object?>[],
};

void main() {
  late AppDatabase db;
  late LessonRepository lessons;
  late ProgressRepository progress;
  var now = DateTime(2026, 10, 20, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 20, 9);
    lessons = LessonRepository(db);
    progress = ProgressRepository(db, OutboxRepository(db), now: () => now);
    await BundleImporter(db).importBundle(moduleBundle());
  });

  tearDown(() => db.close());

  test('lessons come in order, each with its status', () async {
    await progress.completeLesson(11);
    await progress.saveReadingPosition(12, 'b1', 0.5);
    final items = await lessons.watchLessons(7).first;
    expect(items.map((i) => i.lesson.id), [11, 12, 13]);
    expect(items.map((i) => i.status), [
      LessonStatus.done,
      LessonStatus.inProgress,
      LessonStatus.fresh,
    ]);
    expect((await lessons.watchResources(7).first).single.title, 'TD 1');
  });

  test('Continue = unfinished lessons (2-98 %), newest first', () async {
    await progress.saveReadingPosition(11, 'b1', 0.4);
    now = now.add(const Duration(minutes: 5));
    await progress.saveReadingPosition(13, 'b1', 0.3);
    now = now.add(const Duration(minutes: 5));
    await progress.saveReadingPosition(12, 'b1', 0.99);
    expect((await lessons.continueItems()).map((c) => c.lesson.id), [13, 11]);
    await progress.completeLesson(13);
    final left = await lessons.continueItems();
    expect(left.map((c) => c.lesson.id), [11]);
    expect(left.single.module.name, 'Chimie');
  });

  test('next lesson follows the position order', () async {
    final first = await lessons.lesson(11);
    final last = await lessons.lesson(13);
    expect((await lessons.nextLesson(first!))?.id, 12);
    expect(await lessons.nextLesson(last!), isNull);
  });

  test(
    'lesson language: wanted, else French, block ids stay the same',
    () async {
      final row = (await lessons.lesson(11))!;
      final ar = LessonContent.of(row, 'ar');
      final en = LessonContent.of(row, 'en');
      expect(ar.title, 'AR 11');
      expect(en.language, 'fr');
      expect(en.title, 'Lecon 11');
      expect(en.unitNumber, 1);
      expect(en.unitTitle, 'Chapitre 1');
      expect(ar.blocks.single['id'], en.blocks.single['id']);
    },
  );
}
