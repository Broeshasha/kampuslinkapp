import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final SupabaseClient supabase;

  const CommentsSheet({
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.supabase
          .from('community_comments')
          .select(
            'content, created_at, profiles(username)',
          )
          .eq('post_id', widget.postId)
          .order('created_at')
          .timeout(const Duration(seconds: 8));

      setState(() {
        _comments = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Comments load error: $e');

      setState(() {
        _error = 'Could not load comments.';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();

    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);

    final userId = widget.supabase.auth.currentUser!.id;

    _controller.clear();

    try {
      await widget.supabase.from('community_comments').insert({
        'post_id': widget.postId,
        'user_id': userId,
        'content': content,
      });

      await _load();
    } catch (e) {
      debugPrint('Comment send error: $e');
    }

    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Comments',
                style: TextStyle(
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
                      : _comments.isEmpty
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
                              itemCount: _comments.length,
                              itemBuilder: (context, i) {
                                final c = _comments[i];

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@${c['profiles']?['username'] ?? 'unknown'}',
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c['content'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
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
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
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

