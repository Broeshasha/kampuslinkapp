import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../providers.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final api = ref.watch(kampusApiProvider);
  return ChatRepository(
    ref.watch(appDatabaseProvider),
    fetch: (moduleId, before) => api == null
        ? Future.error(const OfflineFailure())
        : api.getChatMessages(moduleId, before),
    post: (moduleId, body, lang, clientId) => api == null
        ? Future.error(const OfflineFailure())
        : api.postChatMessage(moduleId, body, lang, clientId),
  );
});
