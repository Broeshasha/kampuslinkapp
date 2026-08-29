import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/comments_sheet.dart';

class MyPostsTab extends StatefulWidget {
  const MyPostsTab({super.key});

  @override
  State<MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<MyPostsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPostIds = {};
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
          .select('*, community_likes(count)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final likes = await _supabase
          .from('community_likes')
          .select('post_id')
          .eq('user_id', userId);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(data).map((p) {
          final likeRows = p['community_likes'] as List?;
          p['like_count'] = likeRows != null && likeRows.isNotEmpty ? likeRows.first['count'] : 0;
          return p;
        }).toList();
        _likedPostIds = Set<String>.from(likes.map((l) => l['post_id'] as String));
        _loading = false;
      });
    } catch (e) {
      debugPrint('MyPostsTab load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final alreadyLiked = _likedPostIds.contains(postId);
    final postIndex = _posts.indexWhere((p) => p['id'] == postId);

    setState(() {
      if (alreadyLiked) {
        _likedPostIds.remove(postId);
        if (postIndex != -1) {
          _posts[postIndex]['like_count'] = (_posts[postIndex]['like_count'] ?? 1) - 1;
        }
      } else {
        _likedPostIds.add(postId);
        if (postIndex != -1) {
          _posts[postIndex]['like_count'] = (_posts[postIndex]['like_count'] ?? 0) + 1;
        }
      }
    });

    try {
      if (alreadyLiked) {
        await _supabase.from('community_likes').delete().eq('post_id', postId).eq('user_id', userId);
      } else {
        await _supabase.from('community_likes').insert({'post_id': postId, 'user_id': userId});
      }
    } catch (e) {
      debugPrint('Like toggle error: $e');
      _load();
    }
  }

  void _openComments(String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(postId: postId, supabase: _supabase),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final username = _supabase.auth.currentUser?.userMetadata?['username'] ?? 'me';
    final text = '${post['content']}\n\n— @$username on KampusLink';

    try {
      final result = await SharePlus.instance.share(ShareParams(text: text));
      if (result.status == ShareResultStatus.unavailable && mounted) {
        await Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing not available here — copied to clipboard instead.')),
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
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
          final liked = _likedPostIds.contains(post['id']);
          final likeCount = post['like_count'] ?? 0;

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(post['id']),
                      child: Row(
                        children: [
                          Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: liked ? AppColors.danger : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            likeCount > 0 ? '$likeCount' : 'Like',
                            style: TextStyle(
                              color: liked ? AppColors.danger : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap: () => _openComments(post['id']),
                      child: const Row(
                        children: [
                          Icon(Icons.mode_comment_outlined, size: 17, color: AppColors.textSecondary),
                          SizedBox(width: 5),
                          Text('Comment', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap: () => _sharePost(post),
                      child: const Row(
                        children: [
                          Icon(Icons.share_outlined, size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 5),
                          Text('Share', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
