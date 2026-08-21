import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPostIds = {};
  bool _loading = true;
  final _composerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final posts = await _supabase
          .from('community_posts')
          .select('id, content, created_at, user_id, '
              'profiles(username, avatar_url, avatar_blurhash)')
          .order('created_at', ascending: false)
          .limit(30);

      final likes = await _supabase
          .from('community_likes')
          .select('post_id')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(posts);
          _likedPostIds = Set<String>.from(likes.map((l) => l['post_id'] as String));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final alreadyLiked = _likedPostIds.contains(postId);

    setState(() {
      if (alreadyLiked) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
    });

    try {
      if (alreadyLiked) {
        await _supabase
            .from('community_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await _supabase
            .from('community_likes')
            .insert({'post_id': postId, 'user_id': userId});
      }
    } catch (_) {
      // Revert on failure
      setState(() {
        if (alreadyLiked) {
          _likedPostIds.add(postId);
        } else {
          _likedPostIds.remove(postId);
        }
      });
    }
  }

  Future<int> _commentCount(String postId) async {
    final result = await _supabase
        .from('community_comments')
        .select('id')
        .eq('post_id', postId);
    return result.length;
  }

  Future<void> _openComposer() async {
    _composerController.clear();
    final posted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New post', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _composerController,
              autofocus: true,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final content = _composerController.text.trim();
                if (content.isEmpty) return;
                final userId = _supabase.auth.currentUser!.id;
                await _supabase
                    .from('community_posts')
                    .insert({'user_id': userId, 'content': content});
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Post', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
    if (posted == true) _load();
  }

  void _openComments(String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CommentsSheet(postId: postId, supabase: _supabase),
    );
  }

  String _timeAgo(String isoDate) {
    final date = DateTime.parse(isoDate);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        children: [
          const Text('Community',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Students, by students',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),

          InkWell(
            onTap: _openComposer,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: AppColors.accent, size: 20),
                  SizedBox(width: 10),
                  Text('Share something with the community...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text('No posts yet — be the first to share something.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),

          ..._posts.map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _postCard(post),
              )),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final profile = post['profiles'];
    final liked = _likedPostIds.contains(post['id']);

    return Container(
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
              ClipOval(
                child: SizedBox(
                  width: 32, height: 32,
                  child: profile?['avatar_url'] != null
                      ? BlurHashImage(
                          imageUrl: profile['avatar_url'],
                          blurhash: profile['avatar_blurhash'])
                      : Container(
                          color: AppColors.background,
                          child: const Icon(Icons.person, size: 18, color: AppColors.textSecondary),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Text('@${profile?['username'] ?? 'unknown'}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(_timeAgo(post['created_at']),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(post['content'], style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: () => _toggleLike(post['id']),
                child: Row(
                  children: [
                    Icon(liked ? Icons.favorite : Icons.favorite_border,
                        size: 18, color: liked ? AppColors.danger : AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text('Like', style: TextStyle(
                        color: liked ? AppColors.danger : AppColors.textSecondary, fontSize: 12)),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final SupabaseClient supabase;
  const _CommentsSheet({required this.postId, required this.supabase});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.supabase
        .from('community_comments')
        .select('content, created_at, profiles(username)')
        .eq('post_id', widget.postId)
        .order('created_at');
    setState(() {
      _comments = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    final userId = widget.supabase.auth.currentUser!.id;
    _controller.clear();
    await widget.supabase.from('community_comments').insert({
      'post_id': widget.postId,
      'user_id': userId,
      'content': content,
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Comments', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      itemBuilder: (context, i) {
                        final c = _comments[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@${c['profiles']?['username'] ?? 'unknown'}',
                                  style: const TextStyle(
                                      color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(c['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}