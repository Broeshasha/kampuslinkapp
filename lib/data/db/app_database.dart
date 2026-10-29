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

  /// Indexes for the hot queries (feed, modules, lessons by module).
  /// IF NOT EXISTS: added to old phones on the next open, no migration.
  static const _indexes = [
    'CREATE INDEX IF NOT EXISTS idx_lessons_module '
        'ON lessons (module_id, position)',
    'CREATE INDEX IF NOT EXISTS idx_cards_module ON cards (module_id)',
    'CREATE INDEX IF NOT EXISTS idx_cards_lesson '
        'ON cards (lesson_id, position)',
    'CREATE INDEX IF NOT EXISTS idx_questions_lesson ON questions (lesson_id)',
    'CREATE INDEX IF NOT EXISTS idx_questions_module ON questions (module_id)',
    'CREATE INDEX IF NOT EXISTS idx_resources_module ON resources (module_id)',
    'CREATE INDEX IF NOT EXISTS idx_glossary_module '
        'ON glossary_entries (module_id)',
    'CREATE INDEX IF NOT EXISTS idx_card_progress_due ON card_progress (due_at)',
    'CREATE INDEX IF NOT EXISTS idx_reading_updated '
        'ON reading_positions (updated_at)',
    'CREATE INDEX IF NOT EXISTS idx_outbox_next '
        'ON outbox (next_attempt_at, seq)',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
  );

  /// Opens the database (and adds the indexes) before the first screen
  /// asks for it. Called from main(), in parallel with the first frame.
  Future<void> warmUp() async {
    await customSelect('SELECT 1').get();
  }

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
