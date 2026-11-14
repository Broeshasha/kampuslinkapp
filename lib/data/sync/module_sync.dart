import '../../core/analytics/analytics.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../db/app_database.dart';
import '../modules/module_repository.dart';
import 'download_failure.dart';
import 'module_downloader.dart';

typedef FetchModules = Future<List<Map<String, dynamic>>> Function();

class ModuleSyncReport {
  const ModuleSyncReport({
    this.downloaded = 0,
    this.failed = const [],
    this.failure,
    this.failures = const {},
    this.tripped = false,
  });

  final int downloaded;
  final List<int> failed;
  final AppFailure? failure;
  final Map<int, DownloadFailure> failures;

  /// B03: the pass stopped early because the server kept failing.
  final bool tripped;
}

/// MASTER_PLAN 7.3 with lead brief 2: module list -> for every module that
/// is not complete in [langs], a manifest-diff download (ModuleDownloader).
/// One failing module never blocks the others; it is resumed next sync.
class ModuleSyncService {
  ModuleSyncService({
    required this.modules,
    required this.downloader,
    required this.fetchModules,
    this.include,
    this.shouldStop,
    this.maxTransientInRow = 3,
  });

  final ModuleRepository modules;
  final ModuleDownloader downloader;
  final FetchModules fetchModules;

  /// Which modules may be downloaded (WP17-A: current semester only);
  /// null = all.
  final bool Function(ModuleRow module)? include;

  /// Pause: no new module is started once this is true.
  final bool Function()? shouldStop;

  /// B03 circuit breaker: after this many modules in a row fail with a
  /// network / server error, the pass stops (no hammering during an outage).
  final int maxTransientInRow;

  Future<ModuleSyncReport> sync(
    List<String> langs, {
    void Function(int moduleId, bool busy)? onBusy,
    void Function(int moduleId, int done, int total)? onProgress,
  }) async {
    final list = await guard(fetchModules);
    switch (list) {
      case Err(:final failure):
        return ModuleSyncReport(failure: failure);
      case Ok(:final value):
        await modules.saveServerList(value);
    }
    final filter = include;
    final todo = [
      for (final m in await modules.needingDownload(langs: langs))
        if (filter == null || filter(m)) m,
    ];
    var downloaded = 0;
    var inRow = 0;
    var tripped = false;
    final failures = <int, DownloadFailure>{};
    for (final m in todo) {
      if (inRow >= maxTransientInRow) {
        tripped = true;
        break;
      }
      if (shouldStop?.call() ?? false) break;
      onBusy?.call(m.id, true);
      final result = await downloader.download(
        m.id,
        langs,
        onProgress: (done, total) => onProgress?.call(m.id, done, total),
      );
      onBusy?.call(m.id, false);
      final failure = result.failure;
      if (failure == null) {
        downloaded++;
        inRow = 0;
        Analytics.log('module_download_complete');
      } else {
        failures[m.id] = failure;
        inRow = failure.transient ? inRow + 1 : 0;
      }
    }
    return ModuleSyncReport(
      downloaded: downloaded,
      failed: failures.keys.toList(),
      failures: failures,
      tripped: tripped,
      failure: failures.isEmpty ? null : const ServerFailure('download'),
    );
  }
}
