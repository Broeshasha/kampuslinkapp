import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger.dart';

/// null = Supabase not available (tests, missing config, init failure).
/// main() overrides it with the real client.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// Web builds get the values from --dart-define (Cloudflare build variables),
/// so they never depend on serving a dotfile. Values are NOT in the repo.
const _urlDefine = String.fromEnvironment('SUPABASE_URL');
const _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

/// SUPABASE_URL + SUPABASE_ANON_KEY (public by design): --dart-define first,
/// then .env (phone / PC). Never throws: on failure the app runs offline-only.
Future<SupabaseClient?> initSupabase() async {
  try {
    var url = _urlDefine;
    var key = _keyDefine;
    var source = 'dart-define';
    if (url.isEmpty || key.isEmpty) {
      source = '.env';
      try {
        await dotenv.load(fileName: '.env');
        url = dotenv.env['SUPABASE_URL'] ?? '';
        key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      } catch (error) {
        appLog.warn('supabase: .env not readable ($error)');
      }
    }
    if (url.isEmpty || key.isEmpty) {
      appLog.error(
        StateError('SUPABASE_URL / SUPABASE_ANON_KEY missing'),
        StackTrace.current,
        reason: 'supabase init',
      );
      return null;
    }
    await Supabase.initialize(url: url, publishableKey: key);
    appLog.info('supabase: ready (from $source)');
    return Supabase.instance.client;
  } catch (error, stack) {
    appLog.error(error, stack, reason: 'supabase init');
    return null;
  }
}
