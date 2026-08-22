import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/avatar_picker.dart';
import '../../core/widgets/searchable_picker.dart';
import '../../core/config/algeria_universities.dart';
import '../../core/config/countries.dart';

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
      // RPC, not the PostgREST embedding shorthand — this is the same
      // pattern proven working by direct SQL testing, guaranteed to
      // return the real joined names instead of silently null.
      final data = await _supabase
          .rpc('get_my_profile', params: {'viewer_id': userId})
          .single();
      debugPrint('ProfileScreen loaded: $data');
      if (mounted) {
        setState(() {
          _profile = data as Map<String, dynamic>;
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

  Future<void> _editCountry() async {
    final result = await SearchablePicker.show<Country>(
      context: context,
      title: 'Select your country',
      items: countries,
      labelBuilder: (c) => c.name,
    );
    if (result == null) return;
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({'country_id': result.id}).eq('id', userId);
    _loadProfile();
  }

  Future<void> _editUniversity() async {
    final result = await SearchablePicker.show<University>(
      context: context,
      title: 'Select your university',
      items: algeriaUniversities,
      labelBuilder: (u) => '${u.name} (${u.city})',
    );
    if (result == null) return;
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({'university_id': result.id}).eq('id', userId);
    _loadProfile();
  }

  Future<void> _editSpeciality() async {
    final result = await SearchablePicker.show<Speciality>(
      context: context,
      title: 'Select your speciality',
      items: algeriaSpecialities,
      labelBuilder: (s) => s.name,
    );
    if (result == null) return;
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({'speciality_id': result.id}).eq('id', userId);
    _loadProfile();
  }

  Future<void> _showLanguagePicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Language', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            ListTile(
              title: const Text('English', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.check, color: AppColors.accent),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Français', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('العربية', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
            const SizedBox(height: 28),

            _sectionCard([
              _editableRow('Country', _profile!['country_name'] ?? 'Not set', _editCountry),
              const Divider(color: AppColors.border, height: 1, indent: 16),
              _editableRow('University', _profile!['university_name'] ?? 'Not set', _editUniversity),
              const Divider(color: AppColors.border, height: 1, indent: 16),
              _editableRow('City', _profile!['university_city'] ?? '—', null),
              const Divider(color: AppColors.border, height: 1, indent: 16),
              _editableRow('Speciality', _profile!['speciality_name'] ?? 'Not set', _editSpeciality),
            ]),

            const SizedBox(height: 20),

            _sectionCard([
              _settingsRow('Language', Icons.language, onTap: _showLanguagePicker),
              const Divider(color: AppColors.border, height: 1, indent: 48),
              _settingsRow('Notifications', Icons.notifications_none),
              const Divider(color: AppColors.border, height: 1, indent: 48),
              _settingsRow('Blocked users', Icons.block),
            ]),

            const SizedBox(height: 20),

            _sectionCard([
              _settingsRow('Privacy Policy', Icons.shield_outlined,
                  onTap: () => _openLink('https://site.kampus-link.com/privacy.html')),
              const Divider(color: AppColors.border, height: 1, indent: 48),
              _settingsRow('Terms of Service', Icons.description_outlined,
                  onTap: () => _openLink('https://site.kampus-link.com/terms.html')),
              const Divider(color: AppColors.border, height: 1, indent: 48),
              _settingsRow('Community Guidelines', Icons.groups_outlined,
                  onTap: () =>
                      _openLink('https://site.kampus-link.com/community-guidelines.html')),
            ]),

            const SizedBox(height: 20),

            _sectionCard([
              _settingsRow('Log out', Icons.logout, danger: true, onTap: () async {
                await _supabase.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );

  Widget _editableRow(String label, String value, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            Row(
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

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