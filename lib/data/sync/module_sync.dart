import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../bundle/bundle_importer.dart';
import '../modules/module_repository.dart';

typedef FetchModules = Future<List<Map<String, dynamic>>> Function();
typedef FetchBundle = Future<Map<String, dynamic>> Function(
  int moduleId,
  List<String> langs,
);

class ModuleSyncReport {
  const ModuleSyncReport({
    this.downloaded = 0,
    this.failed = const [],
    this.failure,
  });

  final int downloaded;
  final List<int> failed;
  final AppFailure? failure;
}

/// MASTER_PLAN 7.3: module list -> compare versions -> download only what is
/// newer ([all]: everything, when the language set changed). One failing
/// module never blocks the others; it is retried next sync.
class ModuleSyncService {
  ModuleSyncService({
    required this.modules,
    required this.importer,
    required this.fetchModules,
    required this.fetchBundle,
  });

  final ModuleRepository modules;
  final BundleImporter importer;
  final FetchModules fetchModules;
  final FetchBundle fetchBundle;

  Future<ModuleSyncReport> sync(
    List<String> langs, {
    void Function(int moduleId, bool busy)? onProgress,
    bool all = false,
  }) async {
    final list = await guard(fetchModules);
    switch (list) {
      case Err(:final failure):
        return ModuleSyncReport(failure: failure);
      case Ok(:final value):
        await modules.saveServerList(value);
    }
    final todo = await modules.needingDownload(all: all);
    var downloaded = 0;
    final failed = <int>[];
    AppFailure? firstFailure;
    for (final m in todo) {
      onProgress?.call(m.id, true);
      final result = await guard<void>(() async {
        final bundle = await fetchBundle(m.id, langs);
        await importer.importBundle(bundle);
      });
      onProgress?.call(m.id, false);
      switch (result) {
        case Ok():
          downloaded++;
        case Err(:final failure):
          failed.add(m.id);
          firstFailure ??= failure;
      }
    }
    return ModuleSyncReport(
      downloaded: downloaded,
      failed: failed,
      failure: firstFailure,
    );
  }
}
