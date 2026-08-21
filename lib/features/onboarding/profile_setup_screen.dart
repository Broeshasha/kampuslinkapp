import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/searchable_picker.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/config/algeria_universities.dart';
import '../../core/config/countries.dart';
import '../../core/config/upload_service.dart';
import '../../core/config/image_processing_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ProfileSetupScreen({super.key, required this.onComplete});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  Timer? _debounce;

  Country? _selectedCountry;
  University? _selectedUniversity;
  Speciality? _selectedSpeciality;
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  bool _submitting = false;
  String? _error;

  Uint8List? _avatarBytes;
  String? _avatarUrl;
  String? _avatarBlurhash;
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final originalBytes = await picked.readAsBytes();
      final processed = ImageProcessingService.process(originalBytes, maxDimension: 512);

      setState(() {
        _avatarBytes = processed.imageBytes;
        _avatarBlurhash = processed.blurhash;
      });

      final url = await UploadService.upload(processed.imageBytes, 'avatars', 'avatar.jpg');
      if (url == null) {
        setState(() => _error = 'Avatar upload failed — you can continue and add one later.');
      }
      setState(() => _avatarUrl = url);
    } catch (e) {
      debugPrint('Avatar upload error: $e');
    } finally {
      setState(() => _uploadingAvatar = false);
    }
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    setState(() => _usernameAvailable = null);
    if (value.trim().length < 3) return;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _checkingUsername = true);
      try {
        final taken = await _supabase
            .rpc('is_username_taken', params: {'check_username': value.trim()});
        if (mounted) {
          setState(() {
            _usernameAvailable = !(taken as bool);
            _checkingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  Future<void> _submitMissingEntry(String type) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Tell us your $type', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Type it here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _supabase.from('missing_entry_suggestions').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'entry_type': type,
          'suggested_value': result,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Thanks — we'll add it soon.")),
          );
        }
      } catch (_) {
        // Non-critical if this fails silently — don't block onboarding over it.
      }
    }
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.length < 3 ||
        _usernameAvailable != true ||
        _selectedCountry == null ||
        _selectedUniversity == null ||
        _selectedSpeciality == null) {
      setState(() => _error = 'Fill in every field with a valid username.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser!.id;
      // upsert, not update — the DB trigger usually creates the profile
      // row instantly, but upsert guarantees this works even if that
      // row isn't there yet for any reason. This is the actual fix for
      // fields silently failing to save.
      await _supabase.from('profiles').upsert({
        'id': userId,
        'username': username,
        'country_id': _selectedCountry!.id,
        'university_id': _selectedUniversity!.id,
        'speciality_id': _selectedSpeciality!.id,
        'avatar_url': _avatarUrl,
        'avatar_blurhash': _avatarBlurhash,
        'onboarding_complete': true,
      });
      widget.onComplete();
    } catch (e) {
      debugPrint('Profile submit error: $e');
      setState(() {
        _error = 'Something went wrong. Try again.';
        _submitting = false;
      });
    }
  }

  Widget _pickerField({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  color: value != null ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.surface,
                      backgroundImage:
                          _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                      child: _avatarBytes == null
                          ? const Icon(Icons.person, color: AppColors.textSecondary, size: 36)
                          : null,
                    ),
                    if (_uploadingAvatar)
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
            ),
            const SizedBox(height: 24),

            const Text('Set up your profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),

            TextField(
              controller: _usernameController,
              onChanged: _onUsernameChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: _checkingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : _usernameAvailable == true
                        ? const Icon(Icons.check_circle, color: AppColors.official)
                        : _usernameAvailable == false
                            ? const Icon(Icons.cancel, color: AppColors.danger)
                            : null,
              ),
            ),
            const SizedBox(height: 16),

            _pickerField(
              label: 'Country',
              value: _selectedCountry?.name,
              onTap: () async {
                final result = await SearchablePicker.show<Country>(
                  context: context,
                  title: 'Select your country',
                  items: countries,
                  labelBuilder: (c) => c.name,
                  onNotListed: () => _submitMissingEntry('country'),
                );
                if (result != null) setState(() => _selectedCountry = result);
              },
            ),
            const SizedBox(height: 16),

            _pickerField(
              label: 'University',
              value: _selectedUniversity != null
                  ? '${_selectedUniversity!.name} (${_selectedUniversity!.city})'
                  : null,
              onTap: () async {
                final result = await SearchablePicker.show<University>(
                  context: context,
                  title: 'Select your university',
                  items: algeriaUniversities,
                  labelBuilder: (u) => '${u.name} (${u.city})',
                  onNotListed: () => _submitMissingEntry('university'),
                );
                if (result != null) setState(() => _selectedUniversity = result);
              },
            ),
            const SizedBox(height: 16),

            _pickerField(
              label: 'Speciality',
              value: _selectedSpeciality?.name,
              onTap: () async {
                final result = await SearchablePicker.show<Speciality>(
                  context: context,
                  title: 'Select your speciality',
                  items: algeriaSpecialities,
                  labelBuilder: (s) => s.name,
                  onNotListed: () => _submitMissingEntry('speciality'),
                );
                if (result != null) setState(() => _selectedSpeciality = result);
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],

            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Finish setup',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}