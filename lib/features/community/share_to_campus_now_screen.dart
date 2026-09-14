import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config/image_processing_service.dart';
import '../../core/config/upload_service.dart';
import '../../core/widgets/responsive_page.dart';

class ShareToCampusNowScreen extends StatefulWidget {
  final String imagePath;

  const ShareToCampusNowScreen({super.key, required this.imagePath});

  @override
  State<ShareToCampusNowScreen> createState() => _ShareToCampusNowScreenState();
}

class _ShareToCampusNowScreenState extends State<ShareToCampusNowScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  bool _posting = false;
  String? _error;

  Future<void> _post() async {
    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'Please open KampusLink and sign in first.';
          _posting = false;
        });
        return;
      }

      final bytes = await File(widget.imagePath).readAsBytes();
      final processed = ImageProcessingService.process(bytes, maxDimension: 1080);

      final url = await UploadService.upload(
        processed.imageBytes,
        'community',
        'post.jpg',
      ).timeout(const Duration(seconds: 15));

      await _supabase.from('community_posts').insert({
        'user_id': userId,
        'content': _controller.text.trim(),
        'image_url': url,
        'image_blurhash': processed.blurhash,
        'is_campus_now': true,
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      }).timeout(const Duration(seconds: 8));

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Share-to-Campus-Now error: $e');
      setState(() {
        _error = 'Could not post. Check your connection and try again.';
        _posting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text('Post to Campus Now'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Visible to your campus for 24 hours',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(widget.imagePath),
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a caption (optional)',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _posting ? null : _post,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}