import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';

class MyPostsTab extends StatefulWidget {
  const MyPostsTab({super.key});

  @override
  State<MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<MyPostsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
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
      final data = await _supabase
          .from('community_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('MyPostsTab load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this post?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('community_posts').delete().eq('id', postId);
        _load();
      } catch (e) {
        debugPrint('Delete post error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete post. Try again.')),
          );
        }
      }
    }
  }

  String _timeAgo(String isoDate) {
    final diff = DateTime.now().difference(DateTime.parse(isoDate));
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_posts.isEmpty) {
      return const Center(
        child: Text("You haven't posted anything yet.",
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _posts.length,
        itemBuilder: (context, i) {
          final post = _posts[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_timeAgo(post['created_at']),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    GestureDetector(
                      onTap: () => _confirmDelete(post['id']),
                      child: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(post['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                if (post['image_url'] != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BlurHashImage(
                      imageUrl: post['image_url'],
                      blurhash: post['image_blurhash'],
                      height: 160,
                      width: double.infinity,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}