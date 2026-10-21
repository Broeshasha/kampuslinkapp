import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
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
  });

  final int downloaded;
  final List<int> failed;
  final AppFailure? failure;
  final Map<int, DownloadFailure> failures;
}

/// MASTER_PLAN 7.3 with lead brief 2: module list -> for every module that
/// is not complete in [langs], a manifest-diff download (ModuleDownloader).
/// One failing module never blocks the others; it is resumed next sync.
class ModuleSyncService {
  ModuleSyncService({
    required this.modules,
    required this.downloader,
    required this.fetchModules,
  });

  final ModuleRepository modules;
  final ModuleDownloader downloader;
  final FetchModules fetchModules;

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
    final todo = await modules.needingDownload(langs: langs);
    var downloaded = 0;
    final failures = <int, DownloadFailure>{};
    for (final m in todo) {
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
      } else {
        failures[m.id] = failure;
      }
    }
    return ModuleSyncReport(
      downloaded: downloaded,
      failed: failures.keys.toList(),
      failures: failures,
      failure: failures.isEmpty ? null : const ServerFailure('download'),
    );
  }
}
