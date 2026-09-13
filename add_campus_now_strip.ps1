$path = "C:\kampuslink\lib\features\home\home_screen.dart"
$raw = Get-Content $path -Raw
$content = $raw -replace "`r`n", "`n"

# --- 1. import ---
$old1 = "import '../../core/widgets/blurhash_image.dart';"
$new1 = "import '../../core/widgets/blurhash_image.dart';`nimport '../profile/user_profile_screen.dart';"

if (-not $content.Contains($old1)) { Write-Host "ABORT: import anchor not found"; exit }
$content = $content.Replace($old1, $new1)

# --- 2. show the strip right after the rate strip ---
$old2 = "                const _RateStrip(),`n"
$new2 = "                const _RateStrip(),`n                const _CampusNowStrip(),`n"

if (-not $content.Contains($old2)) { Write-Host "ABORT: rate-strip anchor not found"; exit }
$content = $content.Replace($old2, $new2)

$content = $content -replace "`n", "`r`n"
Set-Content -Path $path -Value $content -NoNewline

# --- 3. append the new widget class at the very end ---
$widgetCode = @'

class _CampusNowStrip extends StatefulWidget {
  const _CampusNowStrip();

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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _rings.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _rings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final ring = _rings[i];
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
'@

Add-Content -Path $path -Value $widgetCode
Write-Host "Campus Now strip added to Home."