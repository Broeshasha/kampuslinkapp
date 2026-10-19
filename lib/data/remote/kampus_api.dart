import 'package:supabase_flutter/supabase_flutter.dart';

/// The backend calls used so far (BACKEND_CONTRACT B + C). Each has a timeout
/// so a dead network becomes an OfflineFailure instead of hanging forever.
class KampusApi {
  KampusApi(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

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
    return (bundle as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> syncProgress(List<Map<String, Object?>> ops) async {
    final results = await _client
        .rpc('sync_progress', params: {'p_ops': ops})
        .timeout(_timeout);
    return results as List<dynamic>;
  }
}
