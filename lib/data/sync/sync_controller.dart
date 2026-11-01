import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../assess/assess_providers.dart';
import '../catalog/catalog.dart';
import '../chat/chat_providers.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import '../remote/kampus_api.dart';
import 'download_failure.dart';
import 'module_downloader.dart';
import 'module_sync.dart';
import 'server_merge.dart';

const _lastSyncKey = 'last_synced_at';
const _contentCheckKey = 'content_checked_at';
const _pausedKey = 'downloads_paused';
const _firstOkKey = 'first_download_ok';
const _assessVersionKey = 'assess_version:';

/// All the languages a lesson can have (the top-up target).
const allContentLanguages = ['ar', 'fr', 'en'];

/// The course language (BACKEND_CONTRACT B: "UI language + content
/// language"). Pilot content is written in French.
// TODO(lead): drop when the server falls back to the source language.
const contentLanguage = 'fr';

/// Feed brief C: at most one content update check a day (plus "Download
/// now" / pull-to-refresh / sign-in / semester or language change).
const contentCheckEvery = Duration(hours: 24);

/// Rough size of one lesson with its cards, questions and extras, used for
/// the size shown before the first download.
// TODO(lead): replace with the measured average (Profile > Downloads).
const lessonBytesEstimate = 40 * 1024;

typedef LessonCount = ({int done, int total});

class SyncState {
  const SyncState({
    this.running = false,
    this.lastSyncedAt,
    this.failure,
    this.downloading = const <int>{},
    this.progress = const <int, LessonCount>{},
    this.failures = const <int, DownloadFailure>{},
    this.paused = false,
    this.downloadedBytes = 0,
  });

  final bool running;
  final DateTime? lastSyncedAt;
  final AppFailure? failure;
  final Set<int> downloading;

  /// Lessons stored / in the manifest, per module being downloaded.
  final Map<int, LessonCount> progress;

  /// The last download failure per module (cleared by a good retry).
  final Map<int, DownloadFailure> failures;

  /// The student paused downloads (Profile > Downloads); kept on the phone.
  final bool paused;

  /// Bytes received this session (uncompressed JSON, for the report).
  final int downloadedBytes;

  SyncState copyWith({
    bool? running,
    DateTime? lastSyncedAt,
    AppFailure? failure,
    bool clearFailure = false,
    Set<int>? downloading,
    Map<int, LessonCount>? progress,
    Map<int, DownloadFailure>? failures,
    bool? paused,
    int? downloadedBytes,
  }) => SyncState(
    running: running ?? this.running,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    failure: clearFailure ? null : (failure ?? this.failure),
    downloading: downloading ?? this.downloading,
    progress: progress ?? this.progress,
    failures: failures ?? this.failures,
    paused: paused ?? this.paused,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
  );
}

/// One sync pass: drain the outbox (+ offline chat), then - at most once a
/// day, or when something is missing on the phone, or when forced - refresh
/// the module list, download what is missing or changed (manifest diff, only
/// changed lesson revs, UI language + course language, mobile data allowed),
/// practice / exams of the modules whose version changed, and merge the
/// server's own progress rows. Only when signed in and online. One pass at
/// a time; Pause stops between two lessons and resumes where it was.
class SyncController extends Notifier<SyncState> {
  bool _stop = false;

  @override
  SyncState build() {
    final prefs = ref.read(sharedPrefsProvider);
    final saved = prefs.getString(_lastSyncKey);
    // The student switched language: download that language now.
    ref.listen<Locale?>(localeControllerProvider, (previous, next) {
      if (previous?.languageCode != next?.languageCode) {
        Future.microtask(() => syncNow(force: true));
      }
    });
    return SyncState(
      lastSyncedAt: saved == null ? null : DateTime.tryParse(saved),
      paused: prefs.getBool(_pausedKey) ?? false,
    );
  }

  /// Last time the content was checked against the server (null = never).
  DateTime? get contentCheckedAt {
    final raw = ref.read(sharedPrefsProvider).getString(_contentCheckKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// True once the student accepted the first full download.
  bool get firstDownloadAccepted =>
      ref.read(sharedPrefsProvider).getBool(_firstOkKey) ?? false;

  List<String> _firstLanguages() {
    final chosen = ref.read(localeControllerProvider)?.languageCode;
    final ui =
        chosen ??
        resolveLocale(
          WidgetsBinding.instance.platformDispatcher.locales,
          const <Locale>[],
        ).languageCode;
    return {ui, contentLanguage}.toList();
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
      shouldStop: () => _stop,
      onBytes: (n) =>
          state = state.copyWith(downloadedBytes: state.downloadedBytes + n),
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

  /// Visible modules not complete on the phone (local check, no network).
  Future<bool> _missingLocally(List<String> langs) async {
    final r = await guard(
      () => ref.read(moduleRepositoryProvider).needingDownload(langs: langs),
    );
    final semester = ref.read(currentSemesterProvider);
    return switch (r) {
      Ok(:final value) => value.any((m) => inSemester(m, semester)),
      Err() => false,
    };
  }

  /// Pause: stops between two lessons; nothing downloads until resumed.
  Future<void> pause() async {
    _stop = true;
    state = state.copyWith(paused: true);
    await ref.read(sharedPrefsProvider).setBool(_pausedKey, true);
  }

  /// "Download now" / "Continue": resumes and checks everything at once.
  Future<void> downloadNow() async {
    _stop = false;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_pausedKey, false);
    await prefs.setBool(_firstOkKey, true);
    state = state.copyWith(paused: false);
    await syncNow(force: true);
  }

  /// Size shown before the first full download: refreshes the module list
  /// (one small call) and estimates the lessons still missing.
  Future<int> estimateFirstDownload() async {
    final api = ref.read(kampusApiProvider);
    final repo = ref.read(moduleRepositoryProvider);
    if (api != null && ref.read(isOnlineProvider)) {
      await guard(() async => repo.saveServerList(await api.getMyModules()));
    }
    final semester = ref.read(currentSemesterProvider);
    final r = await guard(() => repo.needingDownload(langs: _firstLanguages()));
    final lessons = switch (r) {
      Ok(:final value) =>
        value
            .where((m) => inSemester(m, semester))
            .fold<int>(0, (sum, m) => sum + m.lessonCount),
      Err() => 0,
    };
    return lessons * lessonBytesEstimate;
  }

  /// [force]: pull-to-refresh, "Download now", sign-in, semester or
  /// language change. Otherwise content is checked at most once a day,
  /// unless something is still missing on the phone (resume).
  Future<void> syncNow({bool force = false}) async {
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
    final langs = _firstLanguages();
    final last = contentCheckedAt;
    final checkContent =
        !state.paused &&
        (force ||
            last == null ||
            DateTime.now().difference(last) >= contentCheckEvery ||
            await _missingLocally(langs));
    if (!checkContent) {
      final now = DateTime.now();
      if (firstFailure == null) {
        await prefs.setString(_lastSyncKey, now.toIso8601String());
      }
      state = state.copyWith(
        running: false,
        lastSyncedAt: firstFailure == null ? now : null,
        failure: firstFailure,
      );
      return;
    }
    _stop = false;
    final service = ModuleSyncService(
      modules: ref.read(moduleRepositoryProvider),
      downloader: downloader,
      fetchModules: api.getMyModules,
      include: (m) => inSemester(m, ref.read(currentSemesterProvider)),
      shouldStop: () => _stop,
    );
    final report = await service.sync(
      langs,
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
    // Practice + mock exams of the current semester (contract file 15),
    // only for modules whose version changed (or when forced).
    if (firstFailure == null && !_stop) {
      await _syncAssess(api, langs, force: force);
    }
    final now = DateTime.now();
    if (firstFailure == null) {
      await prefs.setString(_lastSyncKey, now.toIso8601String());
      if (!_stop) {
        await prefs.setString(_contentCheckKey, now.toIso8601String());
      }
    }
    state = state.copyWith(
      running: false,
      lastSyncedAt: firstFailure == null ? now : null,
      failure: firstFailure,
    );
  }

  Future<void> _syncAssess(
    KampusApi api,
    List<String> langs, {
    bool force = false,
  }) async {
    final store = ref.read(assessStoreProvider);
    final db = ref.read(appDatabaseProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final semester = ref.read(currentSemesterProvider);
    final modules = [
      for (final m in await db.select(db.modules).get())
        if (inSemester(m, semester)) m,
    ];
    final langKey = (langs.toSet().toList()..sort()).join(',');
    for (final m in modules) {
      if (_stop) return;
      final key = '$_assessVersionKey${m.id}';
      final stamp = '${m.serverVersion}|$langKey';
      if (!force && prefs.getString(key) == stamp) continue;
      final r = await guard(() async {
        final manifest = await api.getModuleManifest(m.id, langs);
        await store.applyManifest(
          m.id,
          manifest,
          fetchPractice: (chapter) => api.getPractice(m.id, chapter, langs),
          fetchPaper: (id) => api.getExamPaper(id, langs),
        );
        await store.mergeServerAttempts(await api.getMyExamAttempts(m.id));
      });
      switch (r) {
        case Ok():
          await prefs.setString(key, stamp);
        case Err(:final failure):
          appLog.info('practice/exams of module ${m.id}: $failure');
      }
    }
  }

  /// "Retry" on one module (module page / onboarding).
  Future<void> retryModule(int moduleId) async {
    final downloader = _downloader();
    if (downloader == null || state.downloading.contains(moduleId)) return;
    _stop = false;
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
