import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/avatar_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('profiles')
          .select('username, avatar_url, avatar_blurhash, '
              'universities(name, city), specialities(name), countries(name)')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _profile = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not load your profile. Pull down to retry.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateAvatar(String url, String blurhash) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({
      'avatar_url': url,
      'avatar_blurhash': blurhash,
    }).eq('id', userId);
    setState(() {
      _profile!['avatar_url'] = url;
      _profile!['avatar_blurhash'] = blurhash;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final university = _profile!['universities'];
    final speciality = _profile!['specialities'];
    final country = _profile!['countries'];

    return ResponsivePage(
      maxWidth: 480,
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          children: [
            Center(
              child: AvatarPicker(
                existingUrl: _profile!['avatar_url'],
                existingBlurhash: _profile!['avatar_blurhash'],
                onUploaded: _updateAvatar,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('@${_profile!['username']}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${university?['name'] ?? 'No university set'} · ${speciality?['name'] ?? '—'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _infoRow('Country', country?['name'] ?? '—'),
                  const Divider(color: AppColors.border, height: 1),
                  _infoRow('City', university?['city'] ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _settingsRow('Language', Icons.language),
                  const Divider(color: AppColors.border, height: 1, indent: 48),
                  _settingsRow('Notifications', Icons.notifications_none),
                  const Divider(color: AppColors.border, height: 1, indent: 48),
                  _settingsRow('Blocked users', Icons.block),
                  const Divider(color: AppColors.border, height: 1, indent: 48),
                  _settingsRow('Log out', Icons.logout, danger: true, onTap: () async {
                    await _supabase.auth.signOut();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      );

  Widget _settingsRow(String label, IconData icon, {bool danger = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.textSecondary),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: danger ? AppColors.danger : Colors.white, fontSize: 14)),
            const Spacer(),
            if (!danger)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}