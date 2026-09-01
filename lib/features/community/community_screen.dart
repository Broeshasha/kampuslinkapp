import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/cached_fetch.dart';
import '../../core/config/outbox_service.dart';
import '../../core/widgets/comments_sheet.dart';
import '../../core/widgets/fullscreen_image_viewer.dart';
import '../../core/config/image_processing_service.dart';
import '../../core/config/upload_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/report_dialog.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => CommunityScreenState();
}

class CommunityScreenState extends State<CommunityScreen> {
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
    final cached = await CachedFetch.readCache('community_posts');
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    try {
      final userId = _supabase.auth.currentUser!.id;

      final posts = await _supabase.rpc(
        'get_community_feed',
        params: {'viewer_id': userId},
      ).timeout(const Duration(seconds: 8));

      final likes = await _supabase
          .from('community_likes')
          .select('post_id')
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 8));

      final postsList = List<Map<String, dynamic>>.from(posts);
      await CachedFetch.writeCache('community_posts', postsList);

      final serverLiked = Set<String>.from(likes.map((l) => l['post_id'] as String));
      final pending = await OutboxService.getAllPending();
      pending.forEach((postId, liked) {
        if (liked) {
          serverLiked.add(postId);
        } else {
          serverLiked.remove(postId);
        }
      });

      final pendingPosts = await OutboxService.getPendingPosts();
      final pendingPostWidgets = pendingPosts.map((p) => {
            'id': p['tempId'],
            'content': p['content'],
            'created_at': p['createdAt'],
            'username': 'You',
            'avatar_url': null,
            'avatar_blurhash': null,
            'like_count': 0,
            'pending': true,
          });

      if (mounted) {
        setState(() {
          _posts = [...pendingPostWidgets, ...postsList];
          _likedPostIds = serverLiked;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Community load error: $e');

      if (mounted) {
        setState(() => _loading = false);
      }
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
          _posts[postIndex]['like_count'] =
              (_posts[postIndex]['like_count'] ?? 1) - 1;
        }
      } else {
        _likedPostIds.add(postId);

        if (postIndex != -1) {
          _posts[postIndex]['like_count'] =
              (_posts[postIndex]['like_count'] ?? 0) + 1;
        }
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
        await _supabase.from('community_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('Like toggle error: $e');
      // Don't revert the tap -- queue it instead. The user's like/unlike
      // stays exactly as they left it and syncs automatically the
      // moment connectivity returns, instead of snapping back and
      // making it look like their tap didn't register.
      await OutboxService.queueLike(postId, !alreadyLiked);
    }
  }

  Future<void> _sharePost(
    BuildContext context,
    Map<String, dynamic> post,
  ) async {
    final text =
        '${post['content']}\n\nâ€” @${post['username']} on KampusLink';

    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text),
      );

      if (result.status == ShareResultStatus.unavailable &&
          context.mounted) {
        await Clipboard.setData(
          ClipboardData(text: text),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing not available here â€” copied to clipboard instead.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');

      // Desktop browsers often lack the Web Share API â€” fall back to clipboard.
      await Clipboard.setData(
        ClipboardData(text: text),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard.'),
          ),
        );
      }
    }
  }

  Future<void> openComposer() async {
    _composerController.clear();

    Uint8List? imageBytes;
    String? imageUrl;
    String? imageBlurhash;
    bool submitting = false;
    bool uploadingImage = false;

    final posted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _composerController,
                autofocus: true,
                maxLines: 4,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (uploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => setModalState(() {
                          imageBytes = null;
                          imageUrl = null;
                          imageBlurhash = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();

                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 90,
                    );

                    if (picked == null) return;

                    setModalState(() => uploadingImage = true);

                    final bytes = await picked.readAsBytes();

                    final processed = ImageProcessingService.process(
                      bytes,
                      maxDimension: 1080,
                    );

                    setModalState(
                      () => imageBytes = processed.imageBytes,
                    );

                    try {
                      final url = await UploadService.upload(
                        processed.imageBytes,
                        'community',
                        'post.jpg',
                      ).timeout(const Duration(seconds: 15));

                      setModalState(() {
                        imageUrl = url;
                        imageBlurhash = processed.blurhash;
                        uploadingImage = false;
                      });
                    } catch (e) {
                      debugPrint('Composer image upload error: $e');
                      setModalState(() {
                        imageBytes = null;
                        uploadingImage = false;
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Couldn't upload photo -- check your connection. You can still post text.",
                            ),
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add a photo',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed:
                    (submitting || uploadingImage)
                        ? null
                        : () async {
                            final content =
                                _composerController.text.trim();

                            if (content.isEmpty) return;

                            setModalState(
                              () => submitting = true,
                            );

                            final userId =
                                _supabase.auth.currentUser!.id;

                            try {
                              await _supabase
                                  .from('community_posts')
                                  .insert({
                                'user_id': userId,
                                'content': content,
                                'image_url': imageUrl,
                                'image_blurhash': imageBlurhash,
                              }).timeout(const Duration(seconds: 8));

                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            } catch (e) {
                              debugPrint(
                                'Post submit error: $e',
                              );

                              if (imageUrl == null) {
                                // Text-only post -- safe to queue and
                                // let it sync automatically later.
                                await OutboxService.queuePost(content);
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } else {
                                // Has an image already uploaded but the
                                // final post failed -- don't silently
                                // lose it, but don't pretend it queued
                                // either since that's not built yet.
                                setModalState(
                                  () => submitting = false,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Couldn't post -- check your connection and try again.",
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (posted == true) {
      _load();
    }
  }

  void _openComments(String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => CommentsSheet(
        postId: postId,
        supabase: _supabase,
      ),
    );
  }

  String _timeAgo(String isoDate) {
    final date = DateTime.parse(isoDate);
    final diff = DateTime.now().difference(date);

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
          90,
        ),
        children: [
          const Text(
            'Community',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Students, by students',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: openComposer,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Share something with the community...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'No posts yet â€” be the first to share something.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ..._posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _postCard(post),
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final liked = _likedPostIds.contains(post['id']);

    final likeCount =
        int.tryParse(
          post['like_count']?.toString() ?? '0',
        ) ??
        0;

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
              GestureDetector(
                onTap: post['avatar_url'] != null
                    ? () => showFullscreenImage(context, post['avatar_url'])
                    : null,
                child: ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: post['avatar_url'] != null
                      ? BlurHashImage(
                          imageUrl: post['avatar_url'],
                          blurhash: post['avatar_blurhash'],
                        )
                      : Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              ),
              const SizedBox(width: 10),
              Text(
                '@${post['username'] ?? 'unknown'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (post['pending'] == true) ...[
                const Text(
                  'Posting...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else
              Text(
                _timeAgo(post['created_at']),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post['content'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (post['image_url'] != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BlurHashImage(
                imageUrl: post['image_url'],
                blurhash: post['image_blurhash'],
                height: 200,
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
                      liked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 18,
                      color: liked
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      likeCount > 0
                          ? '$likeCount'
                          : 'Like',
                      style: TextStyle(
                        color: liked
                            ? AppColors.danger
                            : AppColors.textSecondary,
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
                    Icon(
                      Icons.mode_comment_outlined,
                      size: 17,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Comment',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                onTap: () => _sharePost(context, post),
                child: const Row(
                  children: [
                    Icon(
                      Icons.share_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Share',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => ReportDialog.show(
                  context: context,
                  targetType: 'community_post',
                  targetId: post['id'],
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}











