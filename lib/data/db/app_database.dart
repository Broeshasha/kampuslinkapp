import 'dart:convert';

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
    FeedSeenEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an executor in tests (NativeDatabase.memory()).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  /// B15 rule (AGENTS.md): a schema change = version + 1, a step in
  /// [migration] onUpgrade, a new drift_schemas/ snapshot and a migration
  /// test. Never drop or recreate a table that holds the student's data.
  @override
  int get schemaVersion => 2;

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
    'CREATE INDEX IF NOT EXISTS idx_feed_seen_last '
        'ON feed_seen_entries (last_ms)',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // One step per version, in order. Old phones run every step they miss.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(feedSeenEntries);
        await _moveFeedSeenOutOfKeyValues();
      }
    },
    beforeOpen: (details) async {
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
  );

  /// v1 -> v2: the 'feed_seen' JSON value becomes rows. A broken value is
  /// dropped (it only tunes the Home order), never blocks the upgrade.
  Future<void> _moveFeedSeenOutOfKeyValues() async {
    final row = await customSelect(
      "SELECT value FROM key_values WHERE name = 'feed_seen'",
    ).getSingleOrNull();
    final raw = row?.read<String>('value');
    if (raw != null) {
      try {
        final v = jsonDecode(raw);
        if (v is Map) {
          final rows = <FeedSeenEntriesCompanion>[];
          for (final e in v.entries) {
            final l = e.value;
            if (l is! List || l.length < 3) continue;
            rows.add(
              FeedSeenEntriesCompanion.insert(
                postKey: '${e.key}',
                lastMs: (l[0] as num).toInt(),
                times: Value((l[1] as num).toInt()),
                today: Value((l[2] as num).toInt()),
                outcome: Value(l.length > 3 ? l[3] as String? : null),
              ),
            );
          }
          await batch(
            (b) => b.insertAllOnConflictUpdate(feedSeenEntries, rows),
          );
        }
      } on Object catch (error) {
        appLog.info('feed_seen not migrated: $error');
      }
    }
    await customStatement("DELETE FROM key_values WHERE name = 'feed_seen'");
  }

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
