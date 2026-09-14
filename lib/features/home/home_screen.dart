import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/feed_cache_service.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/blurhash_image.dart';
import '../profile/user_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/image_processing_service.dart';
import '../../core/config/upload_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _campusNowKey = GlobalKey<_CampusNowStripState>();
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
    _campusNowKey.currentState?._load();
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
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
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

                const _RateStrip(),
                _CampusNowStrip(key: _campusNowKey),

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
                            child: _PostCard(post: p),
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

}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  static ({Color color, String label, IconData icon}) _trustMeta(String trust) {
    switch (trust) {
      case 'official':
        return (color: AppColors.official, label: 'Official', icon: Icons.verified);
      case 'verified':
        return (color: AppColors.verified, label: 'Verified', icon: Icons.check_circle);
      default:
        return (color: AppColors.community, label: 'Community', icon: Icons.groups);
    }
  }

  static IconData _categoryIcon(String category) {
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

  static String? _faviconUrl(String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) return null;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.isEmpty) return null;
    return 'https://logo.clearbit.com/${uri.host}';
  }

  static Color _sourceColor(String name) {
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

  /// True if [text] would need more than 2 lines at [maxWidth] with [style].
  bool _isOverflowing(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final trust = _trustMeta(post['trust_label']);
    final imageUrl = post['image_url'] as String?;
    final content = post['content'] as String?;
    final sourceUrl = post['source_url'] as String?;
    final sourceName = post['source_name'] as String? ?? 'Source';
    final favicon = _faviconUrl(sourceUrl);
    const descStyle =
        TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.45);

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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final overflowing = _isOverflowing(content, descStyle, constraints.maxWidth);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            style: descStyle,
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                          if (overflowing) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => setState(() => _expanded = !_expanded),
                              child: Text(
                                _expanded ? 'Show less' : 'Read more',
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _expanded ? 'Summarized by AI' : 'AI',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontStyle: FontStyle.italic),
                      ),
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

/// Small, self-contained "$1 ~ X DA" strip shown near the top of Home.
/// Hides itself entirely if there's no rate yet (cache or network) -- never
/// shows a broken/placeholder state.
class _RateStrip extends StatefulWidget {
  const _RateStrip();

  @override
  State<_RateStrip> createState() => _RateStripState();
}

class _RateStripState extends State<_RateStrip> {
  static const _cacheKey = 'usd_street_rate';
  double? _buyRate;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  Future<void> _loadRate() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getDouble(_cacheKey);
    if (cached != null && mounted) {
      setState(() => _buyRate = cached);
    }
    try {
      final data = await Supabase.instance.client
          .from('exchange_rates')
          .select('buy_rate')
          .eq('currency', 'USD')
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (data == null) return;
      final rate = (data['buy_rate'] as num).toDouble();
      if (!mounted) return;
      setState(() => _buyRate = rate);
      await prefs.setDouble(_cacheKey, rate);
    } catch (_) {
      // Keep whatever the cache gave us -- not critical enough to surface an error.
    }
  }

  void _showInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('About this rate',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text(
              'This is the informal (street) market rate observed at Square '
              'Port-Said in Algiers -- not the official Bank of Algeria rate. '
              'Rates can vary slightly in other cities and change daily.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_buyRate == null) return const SizedBox.shrink();
    final rounded = _buyRate!.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Text('\$1 ~ $rounded DA',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('- Street rate, Algiers',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: _showInfo,
            child: const Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CampusNowStrip extends StatefulWidget {
  const _CampusNowStrip({super.key});

  @override
  State<_CampusNowStrip> createState() => _CampusNowStripState();
}

class _CampusNowStripState extends State<_CampusNowStrip> {
  final _supabase = Supabase.instance.client;
  static const _seenPrefsKey = 'campus_now_seen_ids';
  static const _totalRings = 10;

  List<Map<String, dynamic>> _rings = [];
  Set<String> _seenIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _seenIds = (prefs.getStringList(_seenPrefsKey) ?? []).toSet();

      final results = await Future.wait([
        _supabase.rpc('get_campus_now_posts', params: {'viewer_id': userId}),
        _supabase.rpc('get_campus_now_fallback',
            params: {'viewer_id': userId, 'limit_count': _totalRings}),
      ]).timeout(const Duration(seconds: 8));

      final posts = List<Map<String, dynamic>>.from(results[0])
          .map((p) => {...p, 'ring_type': 'post'})
          .toList();

      final postUserIds = posts.map((p) => p['user_id']).toSet();

      final fallback = List<Map<String, dynamic>>.from(results[1])
          .where((f) => !postUserIds.contains(f['user_id']))
          .map((f) => {...f, 'ring_type': 'profile'})
          .toList();

      final remaining = _totalRings - posts.length;
      final rings = [
        ...posts,
        ...fallback.take(remaining < 0 ? 0 : remaining),
      ];

      setState(() {
        _rings = rings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Campus Now load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _markSeen(String postId) async {
    if (_seenIds.contains(postId)) return;
    setState(() => _seenIds.add(postId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenPrefsKey, _seenIds.toList());
  }

  void _openPost(Map<String, dynamic> post) {
    _markSeen(post['id']);
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: post['image_url'] != null
                    ? BlurHashImage(
                        imageUrl: post['image_url'],
                        blurhash: post['image_blurhash'],
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          post['content'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: post['avatar_url'] != null
                            ? BlurHashImage(
                                imageUrl: post['avatar_url'],
                                blurhash: post['avatar_blurhash'],
                              )
                            : Container(color: AppColors.surface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '@${post['username'] ?? 'unknown'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (post['image_url'] != null && (post['content'] as String?)?.isNotEmpty == true)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Text(
                    post['content'],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openQuickPostSheet() async {
    final controller = TextEditingController();
    Uint8List? imageBytes;
    String? imageUrl;
    String? imageBlurhash;
    bool uploadingImage = false;
    bool posting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post to Campus Now',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Visible to your campus for 24 hours',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "What's happening?",
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(imageBytes!,
                          height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    if (uploadingImage)
                      const Positioned.fill(
                        child: Center(
                            child: CircularProgressIndicator(color: AppColors.accent)),
                      ),
                  ],
                )
              else
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                    if (picked == null) return;

                    setModalState(() => uploadingImage = true);
                    final bytes = await picked.readAsBytes();
                    final processed =
                        ImageProcessingService.process(bytes, maxDimension: 1080);
                    setModalState(() => imageBytes = processed.imageBytes);

                    try {
                      final url = await UploadService.upload(
                        processed.imageBytes,
                        'community',
                        'post.jpg',
                      ).timeout(const Duration(seconds: 15));
                      setModalState(() {
                        imageUrl = url;
                        imageBlurhash = processed.blurhash;
                        uploadingImage = false;
                      });
                    } catch (e) {
                      debugPrint('Quick post image upload error: $e');
                      setModalState(() {
                        imageBytes = null;
                        uploadingImage = false;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Add a photo',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (posting || uploadingImage)
                    ? null
                    : () async {
                        final text = controller.text.trim();
                        if (text.isEmpty && imageUrl == null) return;

                        setModalState(() => posting = true);
                        final userId = _supabase.auth.currentUser!.id;

                        try {
                          await _supabase.from('community_posts').insert({
                            'user_id': userId,
                            'content': text,
                            'image_url': imageUrl,
                            'image_blurhash': imageBlurhash,
                            'is_campus_now': true,
                            'expires_at': DateTime.now()
                                .add(const Duration(hours: 24))
                                .toIso8601String(),
                          }).timeout(const Duration(seconds: 8));

                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _load();
                        } catch (e) {
                          debugPrint('Quick post error: $e');
                          setModalState(() => posting = false);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Post'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _rings.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return GestureDetector(
              onTap: _openQuickPostSheet,
              child: SizedBox(
                width: 62,
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1),
                        color: AppColors.surface,
                      ),
                      child: const Icon(Icons.add, color: AppColors.accent, size: 26),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Post',
                      maxLines: 1,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            );
          }

          final ring = _rings[i - 1];
          final isPost = ring['ring_type'] == 'post';
          final isUnseen = isPost && !_seenIds.contains(ring['id']);

          return GestureDetector(
            onTap: () {
              if (isPost) {
                _openPost(ring);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: ring['user_id']),
                  ),
                );
              }
            },
            child: SizedBox(
              width: 62,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUnseen ? AppColors.accent : AppColors.border,
                        width: isUnseen ? 2 : 1,
                      ),
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: ring['avatar_url'] != null
                            ? BlurHashImage(
                                imageUrl: ring['avatar_url'],
                                blurhash: ring['avatar_blurhash'],
                              )
                            : Container(
                                color: AppColors.surface,
                                child: const Icon(Icons.person,
                                    size: 24, color: AppColors.textSecondary),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ring['username'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
