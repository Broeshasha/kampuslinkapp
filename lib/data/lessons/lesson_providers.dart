import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers.dart';
import 'lesson_repository.dart';

final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => LessonRepository(ref.watch(appDatabaseProvider)),
);

final moduleProvider = StreamProvider.family<ModuleRow?, int>(
  (ref, id) => ref.watch(lessonRepositoryProvider).watchModule(id),
);

final lessonsProvider = StreamProvider.family<List<LessonItem>, int>(
  (ref, moduleId) => ref.watch(lessonRepositoryProvider).watchLessons(moduleId),
);

final resourcesProvider = StreamProvider.family<List<ResourceRow>, int>(
  (ref, moduleId) =>
      ref.watch(lessonRepositoryProvider).watchResources(moduleId),
);

final lessonDoneProvider = StreamProvider.family<bool, int>(
  (ref, lessonId) => ref.watch(lessonRepositoryProvider).watchDone(lessonId),
);
