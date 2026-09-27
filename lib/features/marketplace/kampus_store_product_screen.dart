import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/skeleton_loader.dart';
import 'kampus_store_checkout_screen.dart';

class KampusStoreProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const KampusStoreProductScreen({super.key, required this.product});

  @override
  State<KampusStoreProductScreen> createState() => _KampusStoreProductScreenState();
}

class _KampusStoreProductScreenState extends State<KampusStoreProductScreen> {
  int _photoIndex = 0;

  // Defensive getters -- never let a missing/wrong-type field crash the page.
  List<String> get _images {
    final raw = widget.product['images'];
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  String get _name => (widget.product['display_name'] as String?)?.trim().isNotEmpty == true
      ? widget.product['display_name']
      : (widget.product['original_name'] as String? ?? 'Product');

  String get _description => (widget.product['display_description'] as String?)?.trim() ?? '';

  num get _price => (widget.product['sell_price'] as num?) ?? 0;

  int get _stock => (widget.product['stock'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    debugPrint('KampusStore product opened: id=${widget.product['id']} '
        'images=${_images.length} name="$_name" descLen=${_description.length}');
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // ---- Image carousel ----
          AspectRatio(
            aspectRatio: 1,
            child: images.isEmpty
                ? Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.image_not_supported,
                        color: AppColors.textSecondary, size: 40),
                  )
                : PageView.builder(
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemCount: images.length,
                    itemBuilder: (context, i) => CachedNetworkImage(
                      imageUrl: images[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonBox(height: double.infinity),
                      errorWidget: (_, __, err) {
                        debugPrint('Image failed to load: ${images[i]} -- $err');
                        return Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.image_not_supported,
                              color: AppColors.textSecondary, size: 40),
                        );
                      },
                    ),
                  ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _photoIndex ? AppColors.accent : AppColors.border,
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Price + urgency ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_price DA',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    if (_stock > 0 && _stock <= 15)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('Only $_stock left',
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),

                const SizedBox(height: 14),

                // ---- Trust badges row ----
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _TrustBadge(icon: Icons.payments_outlined, label: 'Pay on delivery'),
                    _TrustBadge(icon: Icons.local_shipping_outlined, label: 'All 58 wilayas'),
                    _TrustBadge(icon: Icons.verified_outlined, label: 'Confirmed by call'),
                  ],
                ),

                const SizedBox(height: 18),

                // ---- Description ----
                if (_description.isNotEmpty) ...[
                  const Text('About this item',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.55)),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(_stock > 0 ? '$_stock in stock' : 'Out of stock',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrimaryButton(
            label: _stock > 0 ? 'Order Now -- Pay on Delivery' : 'Out of Stock',
            icon: Icons.shopping_bag_outlined,
            onPressed: _stock > 0
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KampusStoreCheckoutScreen(product: widget.product),
                      ),
                    );
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }
}