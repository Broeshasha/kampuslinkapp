import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 8));

      final items = List<Map<String, dynamic>>.from(data);

      final actorIds = items
          .map((n) => n['actor_id'])
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      Map<String, String> usernames = {};
      if (actorIds.isNotEmpty) {
        final actors = await _supabase
            .from('profiles')
            .select('id, username')
            .inFilter('id', actorIds);
        for (final a in actors) {
          usernames[a['id']] = a['username'] ?? 'Someone';
        }
      }

      for (final n in items) {
        n['_actor_username'] = usernames[n['actor_id']];
      }

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }

      final unreadIds = items.where((n) => n['read'] == false).map((n) => n['id']).toList();
      if (unreadIds.isNotEmpty) {
        await _supabase.from('notifications').update({'read': true}).inFilter('id', unreadIds);
      }
    } catch (e) {
      debugPrint('Notifications load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment_like':
        return Icons.favorite;
      case 'comment':
        return Icons.mode_comment_outlined;
      case 'reply':
        return Icons.reply;
      case 'message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_none;
    }
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(isoDate));
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text('No notifications yet.',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: AppColors.border, height: 1, indent: 68),
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.surface,
                            child: Icon(_iconFor(n['type']), color: AppColors.accent, size: 18),
                          ),
                          title: Text(
                            n['body'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            _timeAgo(n['created_at']),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}