import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../catalog/catalog.dart';
import '../chat/chat_providers.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import 'download_failure.dart';
import 'module_downloader.dart';
import 'module_sync.dart';
import 'server_merge.dart';

const _lastSyncKey = 'last_synced_at';

/// All the languages a lesson can have (the top-up target).
const allContentLanguages = ['ar', 'fr', 'en'];

typedef LessonCount = ({int done, int total});

class SyncState {
  const SyncState({
    this.running = false,
    this.lastSyncedAt,
    this.failure,
    this.downloading = const <int>{},
    this.progress = const <int, LessonCount>{},
    this.failures = const <int, DownloadFailure>{},
  });

  final bool running;
  final DateTime? lastSyncedAt;
  final AppFailure? failure;
  final Set<int> downloading;

  /// Lessons stored / in the manifest, per module being downloaded.
  final Map<int, LessonCount> progress;

  /// The last download failure per module (cleared by a good retry).
  final Map<int, DownloadFailure> failures;

  SyncState copyWith({
    bool? running,
    DateTime? lastSyncedAt,
    AppFailure? failure,
    bool clearFailure = false,
    Set<int>? downloading,
    Map<int, LessonCount>? progress,
    Map<int, DownloadFailure>? failures,
  }) => SyncState(
    running: running ?? this.running,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    failure: clearFailure ? null : (failure ?? this.failure),
    downloading: downloading ?? this.downloading,
    progress: progress ?? this.progress,
    failures: failures ?? this.failures,
  );
}

/// One sync pass: drain the outbox (+ offline chat), refresh the module
/// list, download what is missing (manifest diff, first {UI language, fr}),
/// merge the server's own progress rows, then top up the other languages
/// on Wi-Fi. Only when signed in and online. One pass at a time.
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    final saved = ref.read(sharedPrefsProvider).getString(_lastSyncKey);
    return SyncState(
      lastSyncedAt: saved == null ? null : DateTime.tryParse(saved),
    );
  }

  List<String> _firstLanguages() {
    final chosen = ref.read(localeControllerProvider)?.languageCode;
    final ui =
        chosen ??
        resolveLocale(
          WidgetsBinding.instance.platformDispatcher.locales,
          const <Locale>[],
        ).languageCode;
    return {ui, 'fr'}.toList();
  }

  ModuleDownloader? _downloader() {
    final api = ref.read(kampusApiProvider);
    if (api == null) return null;
    return ModuleDownloader(
      ref.read(appDatabaseProvider),
      ref.read(bundleImporterProvider),
      fetchManifest: api.getModuleManifest,
      fetchLesson: api.getLessonBundle,
      fetchExtras: api.getModuleExtras,
      fetchBundle: api.getModuleBundle,
    );
  }

  void _busy(int id, bool busy) {
    final next = {...state.downloading};
    if (busy) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = state.copyWith(downloading: next);
  }

  void _progress(int id, int done, int total) {
    state = state.copyWith(
      progress: {...state.progress, id: (done: done, total: total)},
    );
  }

  Future<bool> _onWifi() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  Future<void> syncNow() async {
    if (state.running) return;
    final api = ref.read(kampusApiProvider);
    final downloader = _downloader();
    if (api == null ||
        downloader == null ||
        !ref.read(isSignedInProvider) ||
        !ref.read(isOnlineProvider)) {
      return;
    }
    final prefs = ref.read(sharedPrefsProvider);
    state = state.copyWith(running: true, clearFailure: true);
    AppFailure? firstFailure;
    final outboxSync = ref.read(outboxSyncProvider);
    if (outboxSync != null) {
      firstFailure = (await outboxSync.flush()).failure;
    }
    // The catalog (years, modules, settings) first: it decides what shows.
    await ref.read(catalogProvider.notifier).refresh();
    // Chat messages typed offline go out with the sync too (MASTER_PLAN 7.8).
    await guard(() async {
      final chat = ref.read(chatRepositoryProvider);
      for (final moduleId in await chat.modulesWithPending()) {
        await chat.sendPending(moduleId);
      }
    });
    final service = ModuleSyncService(
      modules: ref.read(moduleRepositoryProvider),
      downloader: downloader,
      fetchModules: api.getMyModules,
      include: (m) => inSemester(m, ref.read(currentSemesterProvider)),
    );
    final report = await service.sync(
      _firstLanguages(),
      onBusy: _busy,
      onProgress: _progress,
    );
    state = state.copyWith(failures: report.failures);
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
    // Other languages: in the background, only on Wi-Fi (lead brief 2, B6).
    if (firstFailure == null && await _onWifi()) {
      await service.sync(allContentLanguages, onBusy: _busy);
    }
    final now = DateTime.now();
    if (firstFailure == null) {
      await prefs.setString(_lastSyncKey, now.toIso8601String());
    }
    state = state.copyWith(
      running: false,
      lastSyncedAt: firstFailure == null ? now : null,
      failure: firstFailure,
    );
  }

  /// "Retry" on one module (module page / onboarding).
  Future<void> retryModule(int moduleId) async {
    final downloader = _downloader();
    if (downloader == null || state.downloading.contains(moduleId)) return;
    _busy(moduleId, true);
    final result = await downloader.download(
      moduleId,
      _firstLanguages(),
      onProgress: (done, total) => _progress(moduleId, done, total),
    );
    _busy(moduleId, false);
    final failures = {...state.failures}..remove(moduleId);
    final failure = result.failure;
    if (failure != null) failures[moduleId] = failure;
    state = state.copyWith(failures: failures);
  }

  /// The reader picked a language this lesson does not have yet.
  Future<DownloadFailure?> topUpLesson(int lessonId, String lang) async {
    final downloader = _downloader();
    if (downloader == null) {
      return DownloadFailure.from(
        const OfflineFailure(),
        moduleId: 0,
        step: 'language $lang for lesson $lessonId',
      );
    }
    return downloader.topUpLesson(lessonId, lang);
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
