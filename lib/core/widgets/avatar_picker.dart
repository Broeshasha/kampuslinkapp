import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../config/upload_service.dart';
import '../config/image_processing_service.dart';
import 'blurhash_image.dart';

/// One shared avatar upload flow — used in Profile Setup and Profile edit.
/// Consolidating this in one place is the actual fix for the earlier
/// "silent failure" bug: every caller gets the same real error surfacing.
class AvatarPicker extends StatefulWidget {
  final String? existingUrl;
  final String? existingBlurhash;
  final void Function(String url, String blurhash) onUploaded;

  const AvatarPicker({
    super.key,
    this.existingUrl,
    this.existingBlurhash,
    required this.onUploaded,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  Uint8List? _localBytes;
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final originalBytes = await picked.readAsBytes();
      final processed = ImageProcessingService.process(originalBytes, maxDimension: 512);
      setState(() => _localBytes = processed.imageBytes);

      final url = await UploadService.upload(processed.imageBytes, 'avatars', 'avatar.jpg');

      if (url == null) {
        setState(() => _error = 'Upload failed — check your connection and try again.');
      } else {
        widget.onUploaded(url, processed.blurhash);
      }
    } catch (e) {
      debugPrint('AvatarPicker error: $e');
      setState(() => _error = 'Something went wrong processing that image.');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _uploading ? null : _pick,
          child: Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: _localBytes != null
                      ? Image.memory(_localBytes!, fit: BoxFit.cover)
                      : widget.existingUrl != null
                          ? BlurHashImage(
                              imageUrl: widget.existingUrl!,
                              blurhash: widget.existingBlurhash,
                            )
                          : Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.person,
                                  color: AppColors.textSecondary, size: 36),
                            ),
                ),
              ),
              if (_uploading)
                const Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ],
    );
  }
}