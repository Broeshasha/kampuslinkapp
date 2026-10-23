import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_failure.dart';
import '../sync/server_merge.dart';

/// The backend calls used so far (BACKEND_CONTRACT A, B, C). Each has a
/// timeout so a dead network becomes an OfflineFailure instead of hanging.
class KampusApi {
  KampusApi(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Map<String, dynamic> _map(Object? v) => (v as Map).cast<String, dynamic>();

  /// null when the profile row does not exist yet.
  Future<Map<String, dynamic>?> getMe() async {
    final me = await _client.rpc('get_me').timeout(_timeout);
    return me == null ? null : _map(me);
  }

  Future<Map<String, dynamic>> getOnboardingOptions() async =>
      _map(await _client.rpc('get_onboarding_options').timeout(_timeout));

  Future<Map<String, dynamic>> completeOnboarding({
    required String username,
    required int universityId,
    required int specialityId,
    required String academicYear,
    required String language,
  }) async => _map(
    await _client
        .rpc(
          'complete_onboarding',
          params: {
            'p_username': username,
            'p_university_id': universityId,
            'p_speciality_id': specialityId,
            'p_academic_year': academicYear,
            'p_language': language,
          },
        )
        .timeout(_timeout),
  );

  /// WP17-A: the student's year (L1..M2) and current semester (LMD pair of
  /// the year). Clears pinned semesters. Returns the new get_me().
  /// Errors: invalid_year, invalid_semester, profile_missing.
  Future<Map<String, dynamic>> setStudyLevel(String year, int semester) async =>
      _map(
        await _client
            .rpc(
              'set_study_level',
              params: {'p_year': year, 'p_semester': semester},
            )
            .timeout(_timeout),
      );

  /// Contract 11 (admins only): the bundle WITH draft lessons and sets.
  Future<Map<String, dynamic>> getModuleBundlePreview(
    int moduleId,
    List<String> langs,
  ) async => _map(
    await _client
        .rpc(
          'get_module_bundle_preview',
          params: {'p_module': moduleId, 'p_langs': langs},
        )
        .timeout(const Duration(seconds: 90)),
  );

  /// The client may update its own study_goal_minutes (row security).
  Future<void> setStudyGoal(int minutes) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({'study_goal_minutes': minutes})
        .eq('id', uid)
        .timeout(_timeout);
  }

  Future<void> setReminders({required bool enabled}) async {
    await _client
        .rpc('set_reminders', params: {'p_enabled': enabled})
        .timeout(_timeout);
  }

  /// Store policy: reachable from Profile. Deletes the account server-side.
  Future<void> deleteMyAccount() async {
    await _client.rpc('delete_my_account').timeout(_timeout);
  }

  Future<void> unregisterPushToken(String token) async {
    await _client
        .rpc('unregister_push_token', params: {'p_token': token})
        .timeout(_timeout);
  }

  /// BACKEND_CONTRACT D: newest first, blocked users already filtered out.
  Future<List<Map<String, dynamic>>> getChatMessages(
    int moduleId,
    DateTime? before, {
    int limit = 50,
  }) async {
    final rows = await _client
        .rpc(
          'get_chat_messages',
          params: {
            'p_module': moduleId,
            'p_before': before?.toUtc().toIso8601String(),
            'p_limit': limit,
          },
        )
        .timeout(_timeout);
    return [for (final r in rows as List) (r as Map).cast<String, dynamic>()];
  }

  /// Always with the phone's client_id: a retry never posts twice.
  Future<Map<String, dynamic>> postChatMessage(
    int moduleId,
    String body,
    String lang,
    String clientId,
  ) async => _map(
    await _client
        .rpc(
          'post_chat_message',
          params: {
            'p_module': moduleId,
            'p_body': body,
            'p_lang': lang,
            'p_client_id': clientId,
          },
        )
        .timeout(_timeout),
  );

  Future<void> deleteChatMessage(String id) async {
    await _client
        .rpc('delete_chat_message', params: {'p_id': id})
        .timeout(_timeout);
  }

  /// Chat translations arrive in this language (profiles.preferred_language).
  Future<void> setLanguage(String lang) async {
    await _client
        .rpc('set_language', params: {'p_lang': lang})
        .timeout(_timeout);
  }

  /// target_type: user | module_message | flashcard_comment | resource.
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const UnauthenticatedFailure();
    await _client
        .from('reports')
        .insert({
          'reporter_id': uid,
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        })
        .timeout(_timeout);
  }

  Future<void> blockUser(String userId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const UnauthenticatedFailure();
    await _client
        .from('blocked_users')
        .insert({'blocker_id': uid, 'blocked_id': userId})
        .timeout(_timeout);
  }

  Future<List<Map<String, dynamic>>> getMyModules() async {
    final rows = await _client.rpc('get_my_modules').timeout(_timeout);
    return [for (final r in rows as List) (r as Map).cast<String, dynamic>()];
  }

  /// File 13: tiny list of the module's lessons with a rev per lesson.
  Future<Map<String, dynamic>> getModuleManifest(
    int moduleId,
    List<String> langs,
  ) async => _map(
    await _client.rpc(
      'get_module_manifest',
      params: {'p_module': moduleId, 'p_langs': langs},
    ),
  );

  /// File 13: ONE lesson (same shape as one element of bundle.lessons).
  Future<Map<String, dynamic>> getLessonBundle(
    int lessonId,
    List<String> langs,
  ) async => _map(
    await _client.rpc(
      'get_lesson_bundle',
      params: {'p_lesson': lessonId, 'p_langs': langs},
    ),
  );

  /// File 13: glossary, carousel sets and resources of a module.
  Future<Map<String, dynamic>> getModuleExtras(
    int moduleId,
    List<String> langs,
  ) async => _map(
    await _client.rpc(
      'get_module_extras',
      params: {'p_module': moduleId, 'p_langs': langs},
    ),
  );

  /// Fallback only (servers without file 13): the whole module at once.
  Future<Map<String, dynamic>> getModuleBundle(
    int moduleId,
    List<String> langs,
  ) async {
    final bundle = await _client
        .rpc(
          'get_module_bundle',
          params: {'p_module': moduleId, 'p_langs': langs},
        )
        .timeout(const Duration(seconds: 90));
    return _map(bundle);
  }

  Future<List<dynamic>> syncProgress(List<Map<String, Object?>> ops) async {
    final results = await _client
        .rpc('sync_progress', params: {'p_ops': ops})
        .timeout(_timeout);
    return results as List<dynamic>;
  }

  /// Every own row of [table] (row security), 1000 per page.
  Future<List<Map<String, dynamic>>> _all(
    String table,
    String columns,
    String orderBy,
  ) async {
    const page = 1000;
    final out = <Map<String, dynamic>>[];
    for (var from = 0; ; from += page) {
      final rows = await _client
          .from(table)
          .select(columns)
          .order(orderBy)
          .range(from, from + page - 1)
          .timeout(_timeout);
      out.addAll([for (final r in rows) Map<String, dynamic>.from(r)]);
      if (rows.length < page) break;
    }
    return out;
  }

  /// MASTER_PLAN 7.6: the student's own progress rows, for ServerMerge.
  Future<ServerProgress> fetchMyProgress() async {
    final cards = await _all(
      'learn_card_progress',
      'card_id, box, due_at, last_reviewed_at',
      'card_id',
    );
    final lessons = await _all(
      'learn_lesson_progress',
      'lesson_id, score',
      'lesson_id',
    );
    final positions = await _all(
      'learn_reading_position',
      'lesson_id, block_id, progress, updated_at',
      'lesson_id',
    );
    final likes = await _all('learn_card_likes', 'card_id', 'card_id');
    final saves = await _all('learn_card_saves', 'card_id', 'card_id');
    int id(Map<String, dynamic> r) => (r['card_id'] as num).toInt();
    // Contract 11 table; older servers do not have it yet.
    var sets = const <Map<String, dynamic>>[];
    try {
      sets = await _all(
        'learn_set_progress',
        'set_id, reached, guess, correct, completed',
        'set_id',
      );
    } on PostgrestException {
      sets = const [];
    }
    return ServerProgress(
      sets: sets,
      cards: cards,
      lessons: lessons,
      positions: positions,
      likes: likes.map(id).toSet(),
      saves: saves.map(id).toSet(),
    );
  }
}
