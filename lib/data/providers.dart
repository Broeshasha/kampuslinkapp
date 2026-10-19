import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bundle/bundle_importer.dart';
import 'db/app_database.dart';
import 'learning/progress_repository.dart';
import 'sync/outbox_repository.dart';

/// One database for the whole app (opened lazily on first query).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(appDatabaseProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
  ),
);

final bundleImporterProvider = Provider<BundleImporter>(
  (ref) => BundleImporter(ref.watch(appDatabaseProvider)),
);

/// "n waiting to sync" (shown quietly in Profile later).
final pendingOpsProvider = StreamProvider<int>(
  (ref) => ref.watch(outboxRepositoryProvider).watchPendingCount(),
);
