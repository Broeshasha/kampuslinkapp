import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    setState(() => _loading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      final data = await _supabase.rpc(
        'get_message_threads',
        params: {
          'viewer_id': userId,
        },
      );

      setState(() {
        _threads = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';

    final diff = DateTime.now().difference(
      DateTime.parse(isoDate),
    );

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }

    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20,
        ),
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          if (_threads.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'No conversations yet.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          ..._threads.map(
            (t) => InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      otherUserId: t['other_user_id'],
                      otherUsername: t['other_username'],
                      otherAvatarUrl: t['other_avatar_url'],
                      otherAvatarBlurhash:
                          t['other_avatar_blurhash'],
                    ),
                  ),
                );

                _load();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: t['other_avatar_url'] != null
                            ? BlurHashImage(
                                imageUrl:
                                    t['other_avatar_url'],
                                blurhash:
                                    t['other_avatar_blurhash'],
                              )
                            : Container(
                                color: AppColors.surface,
                                child: const Icon(
                                  Icons.person,
                                  color:
                                      AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${t['other_username']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t['last_message'] ?? '',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color:
                                  AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(
                          _timeAgo(t['last_message_at']),
                          style: const TextStyle(
                            color:
                                AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if ((t['unread_count'] ?? 0) > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${t['unread_count']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}