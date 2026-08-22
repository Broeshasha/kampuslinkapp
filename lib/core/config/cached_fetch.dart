import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Generic cache-first fetch: returns cached data instantly (if any),
/// then refreshes from the network and updates the cache. One reusable
/// pattern instead of hand-rolling it per screen.
class CachedFetch {
  static Future<List<Map<String, dynamic>>> readCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> writeCache(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_$key', jsonEncode(data));
  }
}