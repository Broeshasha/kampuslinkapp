import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/config/upload_service.dart';
import '../../core/config/image_processing_service.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'other';
  bool _submitting = false;
  String? _error;

  static const _minPhotos = 1;
  static const _maxPhotos = 3;

  final List<_ListingPhoto> _photos = [];

  final _categories = const [
    ('electronics', 'Electronics'),
    ('furniture', 'Furniture'),
    ('books', 'Books'),
    ('clothing', 'Clothing'),
    ('kitchen', 'Kitchen'),
    ('transport', 'Transport'),
    ('other', 'Other'),
  ];

  Future<void> _addPhoto() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 90, limit: remaining);
    if (picked.isEmpty) return;

    // limit isn't guaranteed to be enforced by every platform picker, so
    // still cap defensively at however many slots are actually free.
    final newSlots = picked.take(remaining).map((file) => _ListingPhoto()..originalPicked = file).toList();

    setState(() => _photos.addAll(newSlots));

    for (final slot in newSlots) {
      await _uploadPhoto(slot);
    }
  }

  Future<void> _uploadPhoto(_ListingPhoto slot) async {
    setState(() {
      slot.uploading = true;
      slot.failed = false;
    });

    try {
      final bytes = await slot.originalPicked!.readAsBytes();

      Uint8List processedBytes;
      String blurhash;
      try {
        final processed = ImageProcessingService.process(bytes, maxDimension: 1080);
        processedBytes = processed.imageBytes;
        blurhash = processed.blurhash;
      } catch (e) {
        // Image decode/resize failed â€” e.g. an unsupported format like HEIC.
        debugPrint('Image processing error: $e');
        setState(() {
          slot.failed = true;
          slot.uploading = false;
          slot.errorLabel = 'Unsupported image format';
        });
        return;
      }

      setState(() => slot.localBytes = processedBytes);

      final url = await UploadService.upload(processedBytes, 'marketplace', 'item.jpg')
          .timeout(const Duration(seconds: 15));

      if (url == null) {
        setState(() {
          slot.failed = true;
          slot.uploading = false;
          slot.errorLabel = 'Upload failed';
        });
        return;
      }

      setState(() {
        slot.url = url;
        slot.blurhash = blurhash;
        slot.uploading = false;
        slot.failed = false;
      });
    } catch (e) {
      debugPrint('Listing photo upload error: $e');
      setState(() {
        slot.failed = true;
        slot.uploading = false;
        slot.errorLabel = 'Something went wrong';
      });
    }
  }

  void _retryPhoto(_ListingPhoto slot) => _uploadPhoto(slot);
  void _removePhoto(_ListingPhoto photo) => setState(() => _photos.remove(photo));

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    final price = int.tryParse(priceText);

    if (title.isEmpty) {
      setState(() => _error = 'Add a title.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price in DA.');
      return;
    }
    final readyPhotos = _photos.where((p) => p.url != null).toList();
    if (readyPhotos.length < _minPhotos) {
      setState(() => _error = 'Add at least $_minPhotos photo and wait for it to finish uploading.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('university_id')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 8));

      await _supabase.from('marketplace_listings').insert({
        'seller_id': userId,
        'title': title,
        'description': _descController.text.trim(),
        'price_dzd': price,
        'category': _category,
        'image_urls': readyPhotos.map((p) => p.url).toList(),
        'image_blurhashes': readyPhotos.map((p) => p.blurhash).toList(),
        'university_id': profile['university_id'],
      }).timeout(const Duration(seconds: 8));

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Listing submit error: $e');
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      maxWidth: 480,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('List an item')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Photos (${_photos.length}/$_maxPhotos, min $_minPhotos)',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._photos.map((p) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _photoTile(p),
                        )),
                    if (_photos.length < _maxPhotos) _addPhotoTile(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Price (DA)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Description (optional)'),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) {
                  final selected = _category == c.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.accent : AppColors.border),
                      ),
                      child: Text(c.$2,
                          style: TextStyle(
                              color: selected ? Colors.white : AppColors.textSecondary,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],

              const SizedBox(height: 28),
              Center(
                child: PrimaryButton(
                  label: 'Publish listing',
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _photoTile(_ListingPhoto photo) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 90, height: 90,
            child: photo.localBytes != null
                ? Image.memory(photo.localBytes!, fit: BoxFit.cover)
                : Container(color: AppColors.surface),
          ),
        ),
        if (photo.uploading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ),
        if (photo.failed)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _retryPhoto(photo),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 18),
                      Text(photo.errorLabel ?? 'Retry',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(photo),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: _addPhoto,
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add, color: AppColors.textSecondary),
      ),
    );
  }
}

class _ListingPhoto {
  Uint8List? localBytes;
  String? url;
  String? blurhash;
  bool uploading = true;
  bool failed = false;
  String? errorLabel;
  XFile? originalPicked;
}


