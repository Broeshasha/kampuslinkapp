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

  static const _minPhotos = 3;
  static const _maxPhotos = 6;

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
    if (_photos.length >= _maxPhotos) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final slot = _ListingPhoto();
    setState(() => _photos.add(slot));

    try {
      final bytes = await picked.readAsBytes();
      final processed = ImageProcessingService.process(bytes, maxDimension: 1080);
      setState(() => slot.localBytes = processed.imageBytes);

      final url = await UploadService.upload(processed.imageBytes, 'marketplace', 'item.jpg');
      if (url == null) {
        setState(() => _photos.remove(slot));
        return;
      }
      setState(() {
        slot.url = url;
        slot.blurhash = processed.blurhash;
        slot.uploading = false;
      });
    } catch (e) {
      debugPrint('Listing photo upload error: $e');
      setState(() => _photos.remove(slot));
    }
  }

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
    if (_photos.length < _minPhotos || _photos.any((p) => p.url == null)) {
      setState(() => _error = 'Add at least $_minPhotos photos and wait for uploads to finish.');
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
          .single();

      await _supabase.from('marketplace_listings').insert({
        'seller_id': userId,
        'title': title,
        'description': _descController.text.trim(),
        'price_dzd': price,
        'category': _category,
        'image_urls': _photos.map((p) => p.url).toList(),
        'image_blurhashes': _photos.map((p) => p.blurhash).toList(),
        'university_id': profile['university_id'],
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Listing submit error: $e');
      setState(() {
        _error = 'Something went wrong. Try again.';
        _submitting = false;
      });
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
                height: 90,
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
}