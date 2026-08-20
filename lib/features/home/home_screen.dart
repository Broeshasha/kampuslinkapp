import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/feed_cache_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  Map<String, dynamic>? _dining;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Show cached posts immediately — works offline.
    final cached = await FeedCacheService.readCache();
    if (cached.isNotEmpty) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
    }

    // Then refresh from network in the background.
    try {
      final userId = _supabase.auth.currentUser?.id;
      final profile = userId == null
          ? null
          : await _supabase.from('profiles').select('university_id').eq('id', userId).maybeSingle();
      final universityId = profile?['university_id'];

      final posts = await _supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      final dining = universityId == null
          ? null
          : await _supabase
              .from('dining_menus')
              .select()
              .eq('university_id', universityId)
              .eq('meal_date', DateTime.now().toIso8601String().split('T')[0])
              .maybeSingle();

      final postsList = List<Map<String, dynamic>>.from(posts);
      await FeedCacheService.writeCache(postsList);

      if (mounted) {
        setState(() {
          _posts = postsList;
          _dining = dining;
          _loading = false;
        });
      }
    } catch (_) {
      // Offline and nothing cached yet — just stop the spinner, show empty state.
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _labelColor(String trust) {
    switch (trust) {
      case 'official':
        return AppColors.official;
      case 'verified':
        return AppColors.verified;
      default:
        return AppColors.community;
    }
  }

  String _labelText(String trust) {
    switch (trust) {
      case 'official':
        return 'Official';
      case 'verified':
        return 'Verified';
      default:
        return 'Community';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        const Text('Good to see you',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        if (_dining != null) _diningCard(_dining!),
        if (_dining != null) const SizedBox(height: 12),

        ..._posts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _postCard(p),
            )),

        if (_posts.isEmpty && _dining == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('Nothing here yet — check back soon.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
      ],
    );
  }

  Widget _diningCard(Map<String, dynamic> dining) {
    final items = List<String>.from(dining['items']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('${dining['meal_type']} today'.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(items.join(' · '), style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _labelColor(post['trust_label']).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_labelText(post['trust_label']),
                    style: TextStyle(
                        color: _labelColor(post['trust_label']),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(post['title'], style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (post['source_name'] != null) ...[
            const SizedBox(height: 4),
            Text(post['source_name'],
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}