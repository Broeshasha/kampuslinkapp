import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final myId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('blocked_users')
          .select('blocked_id, profiles!blocked_users_blocked_id_fkey(username, avatar_url, avatar_blurhash)')
          .eq('blocker_id', myId);

      setState(() {
        _blocked = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('BlockedUsersScreen load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String blockedId) async {
    final myId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('blocked_users')
        .delete()
        .eq('blocker_id', myId)
        .eq('blocked_id', blockedId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Blocked Users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _blocked.isEmpty
              ? const Center(
                  child: Text("You haven't blocked anyone.",
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _blocked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final row = _blocked[i];
                    final profile = row['profiles'] as Map<String, dynamic>?;
                    final username = profile?['username'] ?? 'Unknown user';
                    final avatarUrl = profile?['avatar_url'];
                    final avatarBlurhash = profile?['avatar_blurhash'];

                    return ListTile(
                      leading: ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: avatarUrl != null
                              ? BlurHashImage(imageUrl: avatarUrl, blurhash: avatarBlurhash)
                              : Container(
                                  color: AppColors.surface,
                                  child: const Icon(Icons.person, color: AppColors.textSecondary),
                                ),
                        ),
                      ),
                      title: Text('@$username', style: const TextStyle(color: Colors.white)),
                      trailing: TextButton(
                        onPressed: () => _unblock(row['blocked_id']),
                        child: const Text('Unblock', style: TextStyle(color: AppColors.accent)),
                      ),
                    );
                  },
                ),
    );
  }
}
