import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/cached_fetch.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await CachedFetch.readCache('message_threads');
    if (cached.isNotEmpty) {
      setState(() {
        _threads = cached;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.rpc('get_message_threads', params: {'viewer_id': userId}).timeout(const Duration(seconds: 8));
      final threads = List<Map<String, dynamic>>.from(data);
      await CachedFetch.writeCache('message_threads', threads);
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    const Text('Messages',
                        style: TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),

                    if (_threads.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text('No conversations yet.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),

                    ..._threads.map((t) => Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      otherUserId: t['other_user_id'],
                                      otherUsername: t['other_username'],
                                      otherAvatarUrl: t['other_avatar_url'],
                                      otherAvatarBlurhash: t['other_avatar_blurhash'],
                                    ),
                                  ),
                                );
                                _load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: SizedBox(
                                        width: 48, height: 48,
                                        child: t['other_avatar_url'] != null
                                            ? BlurHashImage(
                                                imageUrl: t['other_avatar_url'],
                                                blurhash: t['other_avatar_blurhash'])
                                            : Container(
                                                color: AppColors.surface,
                                                child: const Icon(Icons.person,
                                                    color: AppColors.textSecondary),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('@${t['other_username']}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 3),
                                          Text(t['last_message'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: AppColors.textSecondary, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_timeAgo(t['last_message_at']),
                                            style: const TextStyle(
                                                color: AppColors.textSecondary, fontSize: 11)),
                                        if ((t['unread_count'] ?? 0) > 0) ...[
                                          const SizedBox(height: 5),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text('${t['unread_count']}',
                                                style:
                                                    const TextStyle(color: Colors.white, fontSize: 10)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(color: AppColors.border, height: 1),
                          ],
                        )),
                  ],
                ),
              ),
      ),
    );
  }
}

