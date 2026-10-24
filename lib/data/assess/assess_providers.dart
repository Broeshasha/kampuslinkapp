import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../sync/sync_controller.dart';
import 'assess_models.dart';
import 'assess_store.dart';

final assessStoreProvider = Provider<AssessStore>(
  (ref) => AssessStore(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
  ),
);

/// Reloaded after every successful sync (new downloads).
void _afterSync(Ref ref) =>
    ref.watch(syncControllerProvider.select((s) => s.lastSyncedAt));

final practiceIndexProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, moduleId) {
      _afterSync(ref);
      return ref.watch(assessStoreProvider).practiceIndex(moduleId);
    });

final examIndexProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, moduleId) {
      _afterSync(ref);
      return ref.watch(assessStoreProvider).examIndex(moduleId);
    });

final practiceChapterProvider =
    FutureProvider.family<List<Map<String, dynamic>>, (int, String)>((
      ref,
      key,
    ) {
      _afterSync(ref);
      return ref.watch(assessStoreProvider).practiceChapter(key.$1, key.$2);
    });

final examPaperProvider = FutureProvider.family<Map<String, dynamic>?, int>((
  ref,
  paperId,
) {
  _afterSync(ref);
  return ref.watch(assessStoreProvider).examPaper(paperId);
});

final examAttemptsProvider = FutureProvider.family<List<ExamAttempt>, int>((
  ref,
  paperId,
) {
  _afterSync(ref);
  return ref.watch(assessStoreProvider).attempts(paperId);
});

final practiceProgressProvider =
    FutureProvider.family<Map<String, dynamic>, int>(
      (ref, practiceId) =>
          ref.watch(assessStoreProvider).practiceProgress(practiceId),
    );
