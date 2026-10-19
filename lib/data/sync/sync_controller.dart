import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/l10n/locale_controller.dart';
import '../providers.dart';
import 'module_sync.dart';

const _lastSyncKey = 'last_synced_at';

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
/// bundles. Only when signed in and online. One pass at a time.
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    final saved = ref.read(sharedPrefsProvider).getString(_lastSyncKey);
    return SyncState(
      lastSyncedAt: saved == null ? null : DateTime.tryParse(saved),
    );
  }

  List<String> _languages() {
    final chosen = ref.read(localeControllerProvider)?.languageCode;
    final ui =
        chosen ??
        resolveLocale(
          WidgetsBinding.instance.platformDispatcher.locales,
          const <Locale>[],
        ).languageCode;
    return {ui, 'fr'}.toList();
  }

  Future<void> syncNow() async {
    if (state.running) return;
    final api = ref.read(kampusApiProvider);
    if (api == null ||
        !ref.read(isSignedInProvider) ||
        !ref.read(isOnlineProvider)) {
      return;
    }
    state = SyncState(running: true, lastSyncedAt: state.lastSyncedAt);
    AppFailure? firstFailure;
    final outboxSync = ref.read(outboxSyncProvider);
    if (outboxSync != null) {
      firstFailure = (await outboxSync.flush()).failure;
    }
    final service = ModuleSyncService(
      modules: ref.read(moduleRepositoryProvider),
      importer: ref.read(bundleImporterProvider),
      fetchModules: api.getMyModules,
      fetchBundle: api.getModuleBundle,
    );
    final report = await service.sync(
      _languages(),
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
    firstFailure ??= report.failure;
    final now = DateTime.now();
    if (firstFailure == null) {
      await ref
          .read(sharedPrefsProvider)
          .setString(_lastSyncKey, now.toIso8601String());
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
