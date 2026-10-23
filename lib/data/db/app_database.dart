import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../core/logging/logger.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Web only: the storage drift picked in this browser (null elsewhere or
/// before the database opens), e.g. opfsShared, sharedIndexedDb,
/// unsafeIndexedDb, inMemory (WP16 E).
final webStorageStatus = ValueNotifier<String?>(null);

/// true when downloads may not survive closing the browser.
bool webStorageUnsafe(String? implementation) =>
    implementation == 'unsafeIndexedDb' || implementation == 'inMemory';

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
      onResult: (result) {
        final name = result.chosenImplementation.name;
        appLog.info(
          'web storage: $name, missing: '
          '${result.missingFeatures.map((f) => f.name).join(', ')}',
        );
        webStorageStatus.value = name;
      },
    ),
  );
}
