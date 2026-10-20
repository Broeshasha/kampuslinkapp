import 'package:drift/drift.dart';

import '../db/app_database.dart';

enum LessonStatus { fresh, inProgress, done }

/// A lesson with the student's local progress on it.
class LessonItem {
  const LessonItem({required this.lesson, this.progress, this.position});

  final LessonRow lesson;
  final LessonProgressRow? progress;
  final ReadingPositionRow? position;

  bool get done => progress?.completed ?? false;
  double get readProgress => position?.progress ?? 0;

  LessonStatus get status => done
      ? LessonStatus.done
      : (position == null ? LessonStatus.fresh : LessonStatus.inProgress);
}

/// One "Continue" entry for Home (MASTER_PLAN 7.7).
class ContinueItem {
  const ContinueItem({
    required this.lesson,
    required this.module,
    required this.position,
  });

  final LessonRow lesson;
  final ModuleRow module;
  final ReadingPositionRow position;
}

/// Lessons, files and resume data: reads ONLY the local database.
class LessonRepository {
  LessonRepository(this._db);

  final AppDatabase _db;

  Stream<ModuleRow?> watchModule(int id) => (_db.select(
    _db.modules,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<LessonItem>> watchLessons(int moduleId) {
    final query =
        _db.select(_db.lessons).join([
            leftOuterJoin(
              _db.lessonProgress,
              _db.lessonProgress.lessonId.equalsExp(_db.lessons.id),
            ),
            leftOuterJoin(
              _db.readingPositions,
              _db.readingPositions.lessonId.equalsExp(_db.lessons.id),
            ),
          ])
          ..where(_db.lessons.moduleId.equals(moduleId))
          ..orderBy([
            OrderingTerm.asc(_db.lessons.position),
            OrderingTerm.asc(_db.lessons.id),
          ]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          LessonItem(
            lesson: r.readTable(_db.lessons),
            progress: r.readTableOrNull(_db.lessonProgress),
            position: r.readTableOrNull(_db.readingPositions),
          ),
      ],
    );
  }

  Future<LessonRow?> lesson(int id) => (_db.select(
    _db.lessons,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ReadingPositionRow?> readingPosition(int lessonId) => (_db.select(
    _db.readingPositions,
  )..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull();

  Stream<bool> watchDone(int lessonId) =>
      (_db.select(_db.lessonProgress)
            ..where((t) => t.lessonId.equals(lessonId)))
          .watchSingleOrNull()
          .map((r) => r?.completed ?? false);

  /// The lesson after [lesson] in the same module, by position.
  Future<LessonRow?> nextLesson(LessonRow lesson) =>
      (_db.select(_db.lessons)
            ..where(
              (t) =>
                  t.moduleId.equals(lesson.moduleId) &
                  t.position.isBiggerThanValue(lesson.position),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.position)])
            ..limit(1))
          .getSingleOrNull();

  Stream<List<ResourceRow>> watchResources(int moduleId) =>
      (_db.select(_db.resources)
            ..where((t) => t.moduleId.equals(moduleId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.type),
              (t) => OrderingTerm.asc(t.title),
            ]))
          .watch();

  /// Unfinished lessons (read 2-98 %, not completed), most recent first.
  Future<List<ContinueItem>> continueItems({int limit = 5}) async {
    final query =
        _db.select(_db.readingPositions).join([
            innerJoin(
              _db.lessons,
              _db.lessons.id.equalsExp(_db.readingPositions.lessonId),
            ),
            innerJoin(
              _db.modules,
              _db.modules.id.equalsExp(_db.lessons.moduleId),
            ),
            leftOuterJoin(
              _db.lessonProgress,
              _db.lessonProgress.lessonId.equalsExp(
                _db.readingPositions.lessonId,
              ),
            ),
          ])
          ..where(
            _db.readingPositions.progress.isBetweenValues(0.02, 0.98) &
                (_db.lessonProgress.completed.isNull() |
                    _db.lessonProgress.completed.equals(false)),
          )
          ..orderBy([OrderingTerm.desc(_db.readingPositions.updatedAt)])
          ..limit(limit);
    final rows = await query.get();
    return [
      for (final r in rows)
        ContinueItem(
          lesson: r.readTable(_db.lessons),
          module: r.readTable(_db.modules),
          position: r.readTable(_db.readingPositions),
        ),
    ];
  }
}
