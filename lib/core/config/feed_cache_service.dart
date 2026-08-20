import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple cache-first pattern for the feed: show what's cached instantly
/// (works offline), then refresh from network and update the cache.
/// This is a lighter-weight version of the full offline-first Drift
/// architecture from the master plan — enough for V1, upgrade later
/// once Community/Marketplace need the same offline treatment.
class FeedCacheService {
  static const _key = 'cached_feed_posts';

  static Future<List<Map<String, dynamic>>> readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> writeCache(List<Map<String, dynamic>> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(posts));
  }
}