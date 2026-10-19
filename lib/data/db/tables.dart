import 'package:drift/drift.dart';

/// Local schema v1 (MASTER_PLAN 7.2). Per-language content is stored as JSON
/// text ({lang: {...}}) exactly as the bundle sends it; screens decode it.

@DataClassName('ModuleRow')
class Modules extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get semester => integer().nullable()();
  TextColumn get ueCategory => text().nullable()();
  TextColumn get academicYear => text().nullable()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  IntColumn get localVersion => integer().withDefault(const Constant(0))();
  IntColumn get lessonCount => integer().withDefault(const Constant(0))();
  IntColumn get lessonsDone => integer().withDefault(const Constant(0))();
  IntColumn get resourceCount => integer().withDefault(const Constant(0))();
  TextColumn get languages => text().withDefault(const Constant(''))();
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LessonRow')
class Lessons extends Table {
  IntColumn get id => integer()();
  IntColumn get moduleId => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  TextColumn get sourceLang => text().nullable()();
  TextColumn get unitJson => text().nullable()();
  IntColumn get estimatedMinutes => integer().nullable()();
  TextColumn get i18nJson => text()();
  TextColumn get resourceLinksJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CardRow')
class Cards extends Table {
  IntColumn get id => integer()();
  IntColumn get lessonId => integer()();
  IntColumn get moduleId => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  TextColumn get i18nJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('QuestionRow')
class Questions extends Table {
  IntColumn get id => integer()();
  IntColumn get lessonId => integer()();
  IntColumn get moduleId => integer()();
  TextColumn get kind => text()();
  IntColumn get correctIndex => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  TextColumn get i18nJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ResourceRow')
class Resources extends Table {
  IntColumn get id => integer()();
  IntColumn get moduleId => integer()();
  TextColumn get type => text()();
  TextColumn get format => text().nullable()();
  TextColumn get title => text()();
  TextColumn get fileUrlsJson => text().withDefault(const Constant('[]'))();
  TextColumn get trustLabel => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get origin => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GlossaryRow')
class GlossaryEntries extends Table {
  IntColumn get id => integer()();
  IntColumn get moduleId => integer()();
  TextColumn get fr => text().nullable()();
  TextColumn get ar => text().nullable()();
  TextColumn get en => text().nullable()();
  TextColumn get definitionJson => text().withDefault(const Constant('{}'))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CardProgressRow')
class CardProgress extends Table {
  IntColumn get cardId => integer()();
  IntColumn get box => integer().withDefault(const Constant(1))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  BoolColumn get liked => boolean().withDefault(const Constant(false))();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {cardId};
}

@DataClassName('LessonProgressRow')
class LessonProgress extends Table {
  IntColumn get lessonId => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get score => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {lessonId};
}

@DataClassName('ReadingPositionRow')
class ReadingPositions extends Table {
  IntColumn get lessonId => integer()();
  TextColumn get blockId => text()();
  RealColumn get progress => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {lessonId};
}

@DataClassName('StudyDayRow')
class StudyDays extends Table {
  TextColumn get day => text()();
  IntColumn get seconds => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

/// Every write that must reach the server waits here first (MASTER_PLAN 7.5).
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get opId => text()();
  IntColumn get seq => integer()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get replaceKey => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

@DataClassName('KeyValueRow')
class KeyValues extends Table {
  TextColumn get name => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}
