import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/cached_fetch.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await CachedFetch.readCache('marketplace_listings');
    if (cached.isNotEmpty) {
      setState(() {
        _listings = cached;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    try {
      final data = await _supabase
          .from('marketplace_listings')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(40);
      final listings = List<Map<String, dynamic>>.from(data);
      await CachedFetch.writeCache('marketplace_listings', listings);
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Marketplace',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_circle, color: AppColors.accent, size: 28),
                  ),
                ],
              ),
            ),
          ),
          if (_listings.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No listings yet -- be the first to sell something.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _listingCard(_listings[i]),
                  childCount: _listings.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _listingCard(Map<String, dynamic> listing) {
    final images = List<String>.from(listing['image_urls']);
    final blurhashes = List<String>.from(listing['image_blurhashes'] ?? []);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: BlurHashImage(
                imageUrl: images.first,
                blurhash: blurhashes.isNotEmpty ? blurhashes.first : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${listing['price_dzd']} DA',
                      style: const TextStyle(
                          color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(listing['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
