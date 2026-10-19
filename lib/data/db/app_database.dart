import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Modules,
    Lessons,
    Cards,
    Questions,
    Resources,
    GlossaryEntries,
    CardProgress,
    LessonProgress,
    ReadingPositions,
    StudyDays,
    Outbox,
    KeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an executor in tests (NativeDatabase.memory()).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
    name: 'kampuslink',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
