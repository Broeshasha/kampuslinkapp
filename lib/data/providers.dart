import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase/supabase_bootstrap.dart';
import 'bundle/bundle_importer.dart';
import 'db/app_database.dart';
import 'learning/progress_repository.dart';
import 'modules/module_repository.dart';
import 'remote/kampus_api.dart';
import 'sync/outbox_repository.dart';
import 'sync/outbox_sync.dart';
import 'sync/sync_results.dart';

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

final moduleRepositoryProvider = Provider<ModuleRepository>(
  (ref) => ModuleRepository(ref.watch(appDatabaseProvider)),
);

/// The Modules tab reads ONLY this (local DB), never the network.
final modulesStreamProvider = StreamProvider<List<ModuleRow>>(
  (ref) => ref.watch(moduleRepositoryProvider).watchModules(),
);

/// null when Supabase is not available (tests, no .env).
final kampusApiProvider = Provider<KampusApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : KampusApi(client);
});

final outboxSyncProvider = Provider<OutboxSync?>((ref) {
  final api = ref.watch(kampusApiProvider);
  if (api == null) return null;
  final bus = ref.watch(syncResultsProvider);
  return OutboxSync(ref.watch(outboxRepositoryProvider), (ops) async {
    final results = await api.syncProgress(ops);
    bus.publish(results);
    return results;
  });
});

/// "n waiting to sync" (shown quietly in Profile later).
final pendingOpsProvider = StreamProvider<int>(
  (ref) => ref.watch(outboxRepositoryProvider).watchPendingCount(),
);
