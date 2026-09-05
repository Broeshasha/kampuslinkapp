import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/feed_cache_service.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/blurhash_image.dart';

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
  String _filter = 'All';

  final _categories = const ['All', 'University', 'Residence', 'Opportunity', 'News'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await FeedCacheService.readCache();
    if (cached.isNotEmpty) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
    }

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
          .limit(20)
          .timeout(const Duration(seconds: 8));

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
      if (mounted) setState(() => _loading = false);
    }
  }

  ({Color color, String label, IconData icon}) _trustMeta(String trust) {
    switch (trust) {
      case 'official':
        return (color: AppColors.official, label: 'Official', icon: Icons.verified);
      case 'verified':
        return (color: AppColors.verified, label: 'Verified', icon: Icons.check_circle);
      default:
        return (color: AppColors.community, label: 'Community', icon: Icons.groups);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'university':
        return Icons.school_outlined;
      case 'residence':
        return Icons.home_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'opportunity':
        return Icons.workspace_premium_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'telegram':
        return Icons.send_outlined;
      default:
        return Icons.newspaper_outlined;
    }
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_filter == 'All') return _posts;
    final key = _filter.toLowerCase();
    return _posts.where((p) => p['category'] == key || (key == 'news' && (p['category'] == 'news' || p['category'] == 'telegram'))).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text('Home',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text("Here's what's relevant to you today",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),

                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final cat = _categories[i];
                      final selected = _filter == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: selected ? AppColors.accent : AppColors.border),
                          ),
                          child: Text(cat,
                              style: TextStyle(
                                  color: selected ? Colors.white : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (_dining != null) ...[
                        _diningCard(_dining!),
                        const SizedBox(height: 12),
                      ],
                      ..._filteredPosts.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _postCard(p),
                          )),
                      if (_filteredPosts.isEmpty && _dining == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, color: AppColors.textSecondary, size: 32),
                                SizedBox(height: 12),
                                Text('Nothing here yet -- check back soon.',
                                    style: TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _diningCard(Map<String, dynamic> dining) {
    final items = List<String>.from(dining['items']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.14),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('${dining['meal_type']} today'.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(item,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  String? _faviconUrl(String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) return null;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.isEmpty) return null;
    return 'https://logo.clearbit.com/${uri.host}';
  }

  Color _sourceColor(String name) {
    const palette = [
      Color(0xFF3E7BFA), Color(0xFFE0654E), Color(0xFF2FAE6B),
      Color(0xFFB851D6), Color(0xFFE0A62F), Color(0xFF29AAB0),
    ];
    return palette[name.codeUnits.fold(0, (a, b) => a + b) % palette.length];
  }

  Widget _sourceBadge(String? favicon, String sourceName) {
    final initial = sourceName.isNotEmpty ? sourceName[0].toUpperCase() : '?';
    final fallback = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _sourceColor(sourceName)),
      child: Text(initial,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
    if (favicon == null) return fallback;
    return ClipOval(
      child: Image.network(
        favicon,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _postCard(Map<String, dynamic> post) {
    final trust = _trustMeta(post['trust_label']);
    final imageUrl = post['image_url'] as String?;
    final content = post['content'] as String?;
    final sourceUrl = post['source_url'] as String?;
    final sourceName = post['source_name'] as String? ?? 'Source';
    final favicon = _faviconUrl(sourceUrl);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: trust.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BlurHashImage(
                imageUrl: imageUrl,
                blurhash: post['image_blurhash'] as String?,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_categoryIcon(post['category']), size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text((post['category'] as String).toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
                    const Spacer(),
                    Icon(trust.icon, size: 13, color: trust.color),
                    const SizedBox(width: 4),
                    Text(trust.label,
                        style: TextStyle(
                            color: trust.color, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(post['title'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3)),
                if (content != null && content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(content,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13.5, height: 1.45)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Summarized by AI',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (sourceUrl != null && sourceUrl.isNotEmpty)
            InkWell(
              onTap: () => _openSource(sourceUrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    _sourceBadge(favicon, sourceName),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Read full story on $sourceName',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_outward, size: 15, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
