import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart';

/// Queue of offline actions waiting to sync. Starts with likes -- the
/// simplest safe case: idempotent, no server-generated ID to reconcile,
/// and only the FINAL desired state matters, so rapid toggling while
/// offline collapses into a single sync per post instead of replaying
/// every tap.
class OutboxService {
  OutboxService._();
  static const _key = 'outbox_likes';
  static bool _listening = false;

  /// Call once at startup (after ConnectivityService.init()) so the
  /// queue drains automatically the moment connectivity returns.
  static void startAutoSync() {
    if (_listening) return;
    _listening = true;
    ConnectivityService.isOnline.addListener(() {
      if (ConnectivityService.isOnline.value) {
        drainQueue();
      }
    });
  }

  static Future<Map<String, bool>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return Map<String, bool>.from(jsonDecode(raw));
  }

  static Future<void> _writeQueue(Map<String, bool> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(queue));
  }

  /// Queue a like/unlike for later sync. Call this from the UI's error
  /// handler INSTEAD of reverting the optimistic update -- the user's
  /// tap stays visually applied until it actually syncs.
  static Future<void> queueLike(String postId, bool liked) async {
    final queue = await _readQueue();
    queue[postId] = liked;
    await _writeQueue(queue);
  }

  /// What the queue currently says about a post, if anything -- lets a
  /// screen show the pending state correctly even after a restart,
  /// before the queue has had a chance to sync.
  static Future<bool?> getPending(String postId) async {
    final queue = await _readQueue();
    return queue[postId];
  }

  /// The whole pending queue in one read, for a screen to overlay onto
  /// its just-loaded liked-post set without one lookup per post.
  static Future<Map<String, bool>> getAllPending() => _readQueue();

  static Future<void> drainQueue() async {
    final queue = await _readQueue();
    if (queue.isEmpty) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final remaining = Map<String, bool>.from(queue);

    for (final entry in queue.entries) {
      try {
        if (entry.value) {
          await supabase.from('community_likes').insert({
            'post_id': entry.key,
            'user_id': userId,
          });
        } else {
          await supabase
              .from('community_likes')
              .delete()
              .eq('post_id', entry.key)
              .eq('user_id', userId);
        }
        remaining.remove(entry.key);
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // Already liked server-side -- the goal state is already true.
          remaining.remove(entry.key);
        } else {
          debugPrint('Outbox: failed to sync like for ${entry.key}: $e');
        }
      } catch (e) {
        debugPrint('Outbox: failed to sync like for ${entry.key}: $e');
      }
    }

    await _writeQueue(remaining);
  }
}
