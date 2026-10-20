import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<List<Map<String, dynamic>>> getMyModules() async {
    final rows = await _client.rpc('get_my_modules').timeout(_timeout);
    return [for (final r in rows as List) (r as Map).cast<String, dynamic>()];
  }

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
    return ServerProgress(
      cards: cards,
      lessons: lessons,
      positions: positions,
      likes: likes.map(id).toSet(),
      saves: saves.map(id).toSet(),
    );
  }
}
