import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/skeleton_loader.dart';

class MyListingsTab extends StatefulWidget {
  const MyListingsTab({super.key});

  @override
  State<MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends State<MyListingsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('marketplace_listings')
          .select()
          .eq('seller_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 8));
      setState(() {
        _listings = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('MyListingsTab load error: $e');
      setState(() {
        _error = 'Could not load your listings. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _markSold(String listingId) async {
    try {
      await _supabase
          .from('marketplace_listings')
          .update({'status': 'sold'})
          .eq('id', listingId);
      _load();
    } catch (e) {
      debugPrint('Mark sold error: $e');
    }
  }

  Future<void> _confirmDelete(String listingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this listing?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('marketplace_listings').delete().eq('id', listingId);
        _load();
      } catch (e) {
        debugPrint('Delete listing error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete listing. Try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SkeletonBox(width: 64, height: 64, borderRadius: BorderRadius.all(Radius.circular(10))),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 14, borderRadius: BorderRadius.all(Radius.circular(4))),
                    SizedBox(height: 8),
                    SkeletonBox(width: 80, height: 12, borderRadius: BorderRadius.all(Radius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            ),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return const Center(
        child: Text("You haven't listed anything yet.",
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _listings.length,
        itemBuilder: (context, i) {
          final listing = _listings[i];
          final images = List<String>.from(listing['image_urls']);
          final blurhashes = List<String>.from(listing['image_blurhashes'] ?? []);
          final isSold = listing['status'] == 'sold';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64, height: 64,
                        child: BlurHashImage(
                          imageUrl: images.first,
                          blurhash: blurhashes.isNotEmpty ? blurhashes.first : null,
                        ),
                      ),
                    ),
                    if (isSold)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('SOLD',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing['title'],
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${listing['price_dzd']} DA',
                          style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                    ],
                  ),
                ),
                if (!isSold)
                  IconButton(
                    onPressed: () => _markSold(listing['id']),
                    icon: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.official),
                    tooltip: 'Mark as sold',
                  ),
                IconButton(
                  onPressed: () => _confirmDelete(listing['id']),
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

