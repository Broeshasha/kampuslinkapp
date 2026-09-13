import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/fullscreen_image_viewer.dart';
import '../../core/widgets/report_dialog.dart';
import '../../core/widgets/comments_sheet.dart';
import '../messages/chat_screen.dart';
import '../../core/widgets/responsive_page.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final viewerId = _supabase.auth.currentUser!.id;

      final profileData = await _supabase
          .rpc(
            'get_user_profile',
            params: {
              'target_user_id': widget.userId,
              'viewer_id': viewerId,
            },
          )
          .timeout(const Duration(seconds: 8));

      final profile = List<Map<String, dynamic>>.from(profileData);
      if (profile.isEmpty) {
        setState(() {
          _error = 'This profile could not be found.';
          _loading = false;
        });
        return;
      }

      final isBlocked = profile.first['is_blocked'] == true;

      List<Map<String, dynamic>> posts = [];
      if (!isBlocked) {
        final postsData = await _supabase
            .rpc(
              'get_user_posts',
              params: {
                'target_user_id': widget.userId,
                'viewer_id': viewerId,
              },
            )
            .timeout(const Duration(seconds: 8));
        posts = List<Map<String, dynamic>>.from(postsData);
      }

      setState(() {
        _profile = profile.first;
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('User profile load error: $e');
      setState(() {
        _error = 'Could not load this profile.';
        _loading = false;
      });
    }
  }

  String _memberSince(String? createdAt) {
    if (createdAt == null) return '';
    final date = DateTime.tryParse(createdAt);
    if (date == null) return '';
    return 'Member since ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
              onPressed: () => ReportDialog.show(
                context: context,
                targetType: 'user',
                targetId: widget.userId,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                )
              : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final profile = _profile!;
    final isBlocked = profile['is_blocked'] == true;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Center(
          child: GestureDetector(
            onTap: profile['avatar_url'] != null
                ? () => showFullscreenImage(context, profile['avatar_url'])
                : null,
            child: ClipOval(
              child: SizedBox(
                width: 84,
                height: 84,
                child: profile['avatar_url'] != null
                    ? BlurHashImage(
                        imageUrl: profile['avatar_url'],
                        blurhash: profile['avatar_blurhash'],
                      )
                    : Container(
                        color: AppColors.surface,
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '@${profile['username'] ?? 'unknown'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (profile['university_name'] != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              [
                profile['university_name'],
                profile['speciality_name'],
                profile['country_name'],
              ].where((v) => v != null).join(' • '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Center(
          child: Text(
            _memberSince(profile['created_at']),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!isBlocked)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      otherUserId: widget.userId,
                      otherUsername: profile['username'] ?? 'User',
                      otherAvatarUrl: profile['avatar_url'],
                      otherAvatarBlurhash: profile['avatar_blurhash'],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (isBlocked)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'This profile is unavailable.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          const Text(
            'Posts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No posts yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._posts.map((post) => _buildPostCard(post)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
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
          if ((post['content'] as String?)?.isNotEmpty == true)
            Text(
              post['content'],
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
          if (post['image_url'] != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showFullscreenImage(context, post['image_url']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BlurHashImage(
                  imageUrl: post['image_url'],
                  blurhash: post['image_blurhash'],
                  height: 180,
                  width: double.infinity,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${post['like_count'] ?? 0}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  builder: (_) => CommentsSheet(
                    postId: post['id'],
                    supabase: _supabase,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${post['comment_count'] ?? 0}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
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