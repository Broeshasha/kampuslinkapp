import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/logger.dart';
import 'db/app_database.dart';

/// Settings that survive a sign-out, an account switch or an account deletion.
const keptPrefs = {'ui_language', 'theme_mode', 'reader_scale_step'};

/// Which student the local tables and caches belong to (B01 / A-01).
const dataOwnerKey = 'local_data_owner_uid';

/// Empties every local table and forgets everything but the device
/// settings (language, theme, text size). [keepSession]: an account switch
/// keeps the new Supabase session (`sb-*`) and `auth_last_*`.
Future<void> wipeLocalData(
  AppDatabase db,
  SharedPreferences prefs, {
  bool keepSession = false,
}) async {
  await db.transaction(() async {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
  });
  for (final key in prefs.getKeys().toList()) {
    if (keptPrefs.contains(key)) continue;
    if (keepSession &&
        (key.startsWith('sb-') || key.startsWith('auth_last_'))) {
      continue;
    }
    await prefs.remove(key);
  }
}

Future<bool>? _claiming;
String? _claimingUid;

/// The phone's data belongs to [uid] from now on. Another student's data
/// (tables, unsent ops, cached stats) is wiped first, so it is never shown
/// to [uid] nor sent with [uid]'s token. Same uid, or no owner yet (a phone
/// updated from an older build): nothing is wiped.
/// Returns true when another student's data was wiped.
Future<bool> claimLocalData(
  String uid,
  AppDatabase db,
  SharedPreferences prefs,
) {
  final running = _claiming;
  if (running != null && _claimingUid == uid) return running;
  _claimingUid = uid;
  return _claiming = _claim(uid, db, prefs).whenComplete(() {
    _claiming = null;
    _claimingUid = null;
  });
}

Future<bool> _claim(String uid, AppDatabase db, SharedPreferences prefs) async {
  final owner = prefs.getString(dataOwnerKey);
  if (owner == uid) return false;
  final other = owner != null && owner.isNotEmpty;
  if (other) {
    appLog.info('local data: another student signed in, wiping the phone');
    await wipeLocalData(db, prefs, keepSession: true);
  }
  await prefs.setString(dataOwnerKey, uid);
  return other;
}
