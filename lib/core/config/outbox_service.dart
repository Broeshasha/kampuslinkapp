import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart';

/// Queue of offline actions waiting to sync.
///
/// Likes: idempotent, no server-generated ID to reconcile, so only the
/// FINAL desired state matters -- rapid toggling while offline collapses
/// into one sync per post.
///
/// Comments: not idempotent (each is new content), so each gets a
/// locally-generated temp ID and stays in its own queue entry until it
/// actually syncs -- multiple pending comments on the same post are all
/// kept, not collapsed.
class OutboxService {
  OutboxService._();
  static const _likesKey = 'outbox_likes';
  static const _commentsKey = 'outbox_comments';
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

  // ---------------- Likes ----------------

  static Future<Map<String, bool>> _readLikeQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_likesKey);
    if (raw == null) return {};
    return Map<String, bool>.from(jsonDecode(raw));
  }

  static Future<void> _writeLikeQueue(Map<String, bool> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_likesKey, jsonEncode(queue));
  }

  /// Queue a like/unlike for later sync. Call this from the UI's error
  /// handler INSTEAD of reverting the optimistic update -- the user's
  /// tap stays visually applied until it actually syncs.
  static Future<void> queueLike(String postId, bool liked) async {
    final queue = await _readLikeQueue();
    queue[postId] = liked;
    await _writeLikeQueue(queue);
  }

  /// What the queue currently says about a post, if anything -- lets a
  /// screen show the pending state correctly even after a restart,
  /// before the queue has had a chance to sync.
  static Future<bool?> getPending(String postId) async {
    final queue = await _readLikeQueue();
    return queue[postId];
  }

  /// The whole pending like queue in one read, for a screen to overlay
  /// onto its just-loaded liked-post set without one lookup per post.
  static Future<Map<String, bool>> getAllPending() => _readLikeQueue();

  // ---------------- Comments ----------------

  static Future<List<Map<String, dynamic>>> _readCommentQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_commentsKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> _writeCommentQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_commentsKey, jsonEncode(queue));
  }

  /// Queue a comment for later sync. Returns the temp ID so the caller
  /// can show it in the UI immediately, marked pending.
  static Future<String> queueComment(String postId, String content) async {
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final queue = await _readCommentQueue();
    queue.add({
      'tempId': tempId,
      'postId': postId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeCommentQueue(queue);
    return tempId;
  }

  /// Pending comments for one post, so a reopened comment sheet still
  /// shows them before they've actually synced.
  static Future<List<Map<String, dynamic>>> getPendingComments(String postId) async {
    final queue = await _readCommentQueue();
    return queue.where((c) => c['postId'] == postId).toList();
  }

  // ---------------- Posts (text-only) ----------------
  //
  // Posts WITH an image are not queued here -- the image upload itself
  // happens the moment it's picked in the composer, which already fails
  // fast and clearly if offline (see community_screen.dart). Deferred
  // image upload on reconnect is a bigger piece for later; this covers
  // the text-only case, which is the common one.

  static const _postsKey = 'outbox_posts';

  static Future<List<Map<String, dynamic>>> _readPostQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postsKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> _writePostQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_postsKey, jsonEncode(queue));
  }

  static Future<String> queuePost(String content) async {
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final queue = await _readPostQueue();
    queue.add({
      'tempId': tempId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writePostQueue(queue);
    return tempId;
  }

  /// All pending posts, for the feed to show at the top before they've
  /// actually synced.
  static Future<List<Map<String, dynamic>>> getPendingPosts() => _readPostQueue();

  // ---------------- Draining ----------------

  static Future<void> drainQueue() async {
    await _drainLikes();
    await _drainComments();
    await _drainPosts();
  }

  static Future<void> _drainPosts() async {
    final queue = await _readPostQueue();
    if (queue.isEmpty) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final remaining = <Map<String, dynamic>>[];

    for (final entry in queue) {
      try {
        await supabase.from('community_posts').insert({
          'user_id': userId,
          'content': entry['content'],
        });
      } catch (e) {
        debugPrint('Outbox: failed to sync post ${entry['tempId']}: $e');
        remaining.add(entry);
      }
    }

    await _writePostQueue(remaining);
  }

  static Future<void> _drainLikes() async {
    final queue = await _readLikeQueue();
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
          remaining.remove(entry.key);
        } else {
          debugPrint('Outbox: failed to sync like for ${entry.key}: $e');
        }
      } catch (e) {
        debugPrint('Outbox: failed to sync like for ${entry.key}: $e');
      }
    }

    await _writeLikeQueue(remaining);
  }

  static Future<void> _drainComments() async {
    final queue = await _readCommentQueue();
    if (queue.isEmpty) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final remaining = <Map<String, dynamic>>[];

    for (final entry in queue) {
      try {
        await supabase.from('community_comments').insert({
          'post_id': entry['postId'],
          'user_id': userId,
          'content': entry['content'],
        });
      } catch (e) {
        debugPrint('Outbox: failed to sync comment ${entry['tempId']}: $e');
        remaining.add(entry);
      }
    }

    await _writeCommentQueue(remaining);
  }
}

