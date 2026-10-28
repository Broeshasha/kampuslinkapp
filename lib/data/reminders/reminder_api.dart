import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';

/// get_reminder_settings / set_reminder_settings (backend contract).
class ReminderApi {
  ReminderApi(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Map<String, dynamic> _map(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  Future<Map<String, dynamic>> get() async =>
      _map(await _client.rpc('get_reminder_settings').timeout(_timeout));

  /// Turning reminders ON clears the back-off on the server.
  Future<Map<String, dynamic>> set({
    required bool enabled,
    String? time,
    List<int>? days,
  }) async => _map(
    await _client
        .rpc(
          'set_reminder_settings',
          params: {'p_enabled': enabled, 'p_time': time, 'p_days': days},
        )
        .timeout(_timeout),
  );
}

final reminderApiProvider = Provider<ReminderApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : ReminderApi(client);
});
