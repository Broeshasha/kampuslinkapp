import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../providers.dart';
import 'module_sync.dart';
import 'server_merge.dart';

const _lastSyncKey = 'last_synced_at';
const _bundleLangsKey = 'bundle_langs';

/// Pilot decision: every module is downloaded in all three languages.
const bundleLanguages = ['ar', 'fr', 'en'];

class SyncState {
  const SyncState({
    this.running = false,
    this.lastSyncedAt,
    this.failure,
    this.downloading = const <int>{},
  });

  final bool running;
  final DateTime? lastSyncedAt;
  final AppFailure? failure;
  final Set<int> downloading;
}

/// One sync pass: drain the outbox, refresh the module list, download newer
/// bundles, then merge the server's own progress rows (MASTER_PLAN 7.6).
/// Only when signed in and online. One pass at a time.
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    final saved = ref.read(sharedPrefsProvider).getString(_lastSyncKey);
    return SyncState(
      lastSyncedAt: saved == null ? null : DateTime.tryParse(saved),
    );
  }

  Future<void> syncNow() async {
    if (state.running) return;
    final api = ref.read(kampusApiProvider);
    if (api == null ||
        !ref.read(isSignedInProvider) ||
        !ref.read(isOnlineProvider)) {
      return;
    }
    final prefs = ref.read(sharedPrefsProvider);
    state = SyncState(running: true, lastSyncedAt: state.lastSyncedAt);
    AppFailure? firstFailure;
    final outboxSync = ref.read(outboxSyncProvider);
    if (outboxSync != null) {
      firstFailure = (await outboxSync.flush()).failure;
    }
    final langsKey = bundleLanguages.join(',');
    final allModules = prefs.getString(_bundleLangsKey) != langsKey;
    final service = ModuleSyncService(
      modules: ref.read(moduleRepositoryProvider),
      importer: ref.read(bundleImporterProvider),
      fetchModules: api.getMyModules,
      fetchBundle: api.getModuleBundle,
    );
    final report = await service.sync(
      bundleLanguages,
      all: allModules,
      onProgress: (id, busy) {
        final next = {...state.downloading};
        if (busy) {
          next.add(id);
        } else {
          next.remove(id);
        }
        state = SyncState(
          running: true,
          lastSyncedAt: state.lastSyncedAt,
          downloading: next,
        );
      },
    );
    if (report.failure == null && allModules) {
      await prefs.setString(_bundleLangsKey, langsKey);
    }
    firstFailure ??= report.failure;
    if (firstFailure == null) {
      final merged = await guard(() async {
        final progress = await api.fetchMyProgress();
        return ServerMerge(ref.read(appDatabaseProvider)).merge(progress);
      });
      switch (merged) {
        case Ok(:final value):
          appLog.info(value.toString());
        case Err(:final failure):
          firstFailure = failure;
      }
    }
    final now = DateTime.now();
    if (firstFailure == null) {
      await prefs.setString(_lastSyncKey, now.toIso8601String());
    }
    state = SyncState(
      lastSyncedAt: firstFailure == null ? now : state.lastSyncedAt,
      failure: firstFailure,
    );
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
