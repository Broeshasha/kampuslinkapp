import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared block action — used from Messages and any user profile view.
class BlockService {
  static Future<bool> blockUser(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF17181B),
        title: const Text('Block this user?', style: TextStyle(color: Colors.white)),
        content: const Text(
          "They won't be able to message you, and you won't see their content.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final myId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('blocked_users').insert({
      'blocker_id': myId,
      'blocked_id': userId,
    });
    return true;
  }
}