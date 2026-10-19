import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger.dart';

/// null = Supabase not available (tests, missing .env, init failure).
/// main() overrides it with the real client.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// Reads SUPABASE_URL + SUPABASE_ANON_KEY (public by design) from .env.
/// Never throws: on failure the app runs offline-only and the error is logged.
Future<SupabaseClient?> initSupabase() async {
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || key.isEmpty) {
      appLog.error(
        StateError('SUPABASE_URL / SUPABASE_ANON_KEY missing in .env'),
        StackTrace.current,
        reason: 'supabase init',
      );
      return null;
    }
    await Supabase.initialize(url: url, publishableKey: key);
    appLog.info('supabase: ready');
    return Supabase.instance.client;
  } catch (error, stack) {
    appLog.error(error, stack, reason: 'supabase init');
    return null;
  }
}
