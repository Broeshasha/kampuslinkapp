import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('profiles')
        .select('username, avatar_url, avatar_blurhash, '
            'universities(name, city), specialities(name), countries(name)')
        .eq('id', userId)
        .single();
    setState(() {
      _profile = data;
      _loading = false;
    });
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

    final university = _profile!['universities'];
    final speciality = _profile!['specialities'];
    final country = _profile!['countries'];

    return ResponsivePage(
      maxWidth: 480,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            AvatarPicker(
              existingUrl: _profile!['avatar_url'],
              existingBlurhash: _profile!['avatar_blurhash'],
              onUploaded: _updateAvatar,
            ),
            const SizedBox(height: 16),
            Text('@${_profile!['username']}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${university?['name'] ?? ''} · ${speciality?['name'] ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _infoRow('Country', country?['name'] ?? '—'),
            _infoRow('City', university?['city'] ?? '—'),
            const SizedBox(height: 32),
            _settingsRow(context, 'Language', Icons.language),
            _settingsRow(context, 'Notifications', Icons.notifications_none),
            _settingsRow(context, 'Blocked users', Icons.block),
            _settingsRow(context, 'Log out', Icons.logout, danger: true, onTap: () async {
              await _supabase.auth.signOut();
            }),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      );

  Widget _settingsRow(BuildContext context, String label, IconData icon,
      {bool danger = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.textSecondary),
            const SizedBox(width: 12),
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