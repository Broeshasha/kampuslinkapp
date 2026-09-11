import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../config/outbox_service.dart';
import 'blurhash_image.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final SupabaseClient supabase;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.supabase,
  });

  @override
  State<CommentsSheet> createState() => CommentsSheetState();
}

class CommentsSheetState extends State<CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final _controller = TextEditingController();

  Map<String, String>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = widget.supabase.auth.currentUser!.id;

      final data = await widget.supabase
          .rpc(
            'get_post_comments',
            params: {
              'post_id_param': widget.postId,
              'viewer_id': userId,
            },
          )
          .timeout(const Duration(seconds: 8));

      final serverComments = List<Map<String, dynamic>>.from(data);

      final pendingLikes = await OutboxService.getAllPendingCommentLikes();
      for (final c in serverComments) {
        final pending = pendingLikes[c['id']];
        if (pending != null) {
          c['liked_by_viewer'] = pending;
        }
      }

      final pending = await OutboxService.getPendingComments(widget.postId);

      setState(() {
        _comments = [
          ...serverComments,
          ...pending.map((p) => {
                'id': null,
                'content': p['content'],
                'created_at': p['createdAt'],
                'username': 'You',
                'avatar_url': null,
                'avatar_blurhash': null,
                'like_count': 0,
                'liked_by_viewer': false,
                'parent_comment_id': p['parentCommentId'],
                'pending': true,
              }),
        ];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Comments load error: $e');

      final pending = await OutboxService.getPendingComments(widget.postId);

      setState(() {
        if (pending.isNotEmpty) {
          _comments = pending
              .map((p) => {
                    'id': null,
                    'content': p['content'],
                    'created_at': p['createdAt'],
                    'username': 'You',
                    'avatar_url': null,
                    'avatar_blurhash': null,
                    'like_count': 0,
                    'liked_by_viewer': false,
                    'parent_comment_id': p['parentCommentId'],
                    'pending': true,
                  })
              .toList();
        } else {
          _error = 'Could not load comments.';
        }
        _loading = false;
      });
    }
  }

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingTo = {'id': commentId, 'username': username};
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _send() async {
    final content = _controller.text.trim();

    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);

    final userId = widget.supabase.auth.currentUser!.id;
    final parentId = _replyingTo?['id'];

    _controller.clear();
    final wasReplyingTo = _replyingTo;
    setState(() => _replyingTo = null);

    try {
      await widget.supabase
          .from('community_comments')
          .insert({
            'post_id': widget.postId,
            'user_id': userId,
            'content': content,
            'parent_comment_id': parentId,
          })
          .timeout(const Duration(seconds: 8));

      await _load();
    } catch (e) {
      debugPrint('Comment send error: $e');
      await OutboxService.queueComment(
        widget.postId,
        content,
        parentCommentId: parentId,
      );
      setState(() {
        _comments.add({
          'id': null,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
          'username': 'You',
          'avatar_url': null,
          'avatar_blurhash': null,
          'like_count': 0,
          'liked_by_viewer': false,
          'parent_comment_id': parentId,
          'pending': true,
        });
        _error = null;
        _replyingTo = wasReplyingTo;
      });
    }

    setState(() => _sending = false);
  }

  Future<void> _toggleCommentLike(String? commentId) async {
    if (commentId == null) return;

    final index = _comments.indexWhere((c) => c['id'] == commentId);
    if (index == -1) return;

    final alreadyLiked = _comments[index]['liked_by_viewer'] == true;
    final userId = widget.supabase.auth.currentUser!.id;

    setState(() {
      _comments[index]['liked_by_viewer'] = !alreadyLiked;
      _comments[index]['like_count'] =
          (_comments[index]['like_count'] ?? 0) + (alreadyLiked ? -1 : 1);
    });

    try {
      if (alreadyLiked) {
        await widget.supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      } else {
        await widget.supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('Comment like toggle error: $e');
      await OutboxService.queueCommentLike(commentId, !alreadyLiked);
    }
  }

  Widget _buildCommentRow(
    Map<String, dynamic> c, {
    required bool isReply,
  }) {
    final isPending = c['pending'] == true;
    final likeCount = c['like_count'] ?? 0;
    final liked = c['liked_by_viewer'] == true;
    final username = c['username'] ?? 'unknown';

    return Padding(
      padding: EdgeInsets.only(
        bottom: 14,
        left: isReply ? 40 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: isReply ? 24 : 30,
              height: isReply ? 24 : 30,
              child: c['avatar_url'] != null
                  ? BlurHashImage(
                      imageUrl: c['avatar_url'],
                      blurhash: c['avatar_blurhash'],
                    )
                  : Container(
                      color: AppColors.background,
                      child: Icon(
                        Icons.person,
                        size: isReply ? 13 : 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Sending...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c['content'],
                  style: TextStyle(
                    color: isPending ? AppColors.textSecondary : Colors.white,
                    fontSize: 14,
                  ),
                ),
                if (!isPending) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleCommentLike(c['id']),
                        child: Row(
                          children: [
                            Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: liked
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                            ),
                            if (likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          final threadParentId =
                              (c['parent_comment_id'] as String?) ?? c['id'];
                          if (threadParentId == null) return;
                          _startReply(threadParentId, username);
                        },
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topLevel =
        _comments.where((c) => c['parent_comment_id'] == null).toList();
    final repliesByParent = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final parentId = c['parent_comment_id'] as String?;
      if (parentId != null) {
        repliesByParent.putIfAbsent(parentId, () => []).add(c);
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _comments.isEmpty
                    ? 'Comments'
                    : 'Comments (${_comments.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                            ),
                          ),
                        )
                      : topLevel.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: topLevel.length,
                              itemBuilder: (context, i) {
                                final c = topLevel[i];
                                final replies =
                                    repliesByParent[c['id']] ?? [];

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildCommentRow(c, isReply: false),
                                    ...replies.map(
                                      (r) =>
                                          _buildCommentRow(r, isReply: true),
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to @${_replyingTo!['username']}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? 'Write a reply...'
                            : 'Write a comment...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.accent,
                          ),
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