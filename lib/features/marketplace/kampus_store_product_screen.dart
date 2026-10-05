import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import 'kampus_store_checkout_screen.dart';

class KampusStoreProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const KampusStoreProductScreen({super.key, required this.product});

  @override
  State<KampusStoreProductScreen> createState() => _KampusStoreProductScreenState();
}

class _KampusStoreProductScreenState extends State<KampusStoreProductScreen> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = (widget.product['images'] is List)
        ? List<String>.from(widget.product['images'])
        : <String>[];
    final name = (widget.product['display_name'] as String?)?.trim().isNotEmpty == true
        ? widget.product['display_name'] as String
        : (widget.product['original_name'] as String? ?? 'Product');
    final description = (widget.product['display_description'] as String?)?.trim() ?? '';
    final price = widget.product['sell_price'];
    final stock = (widget.product['stock'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: images.isEmpty
                    ? Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary),
                      )
                    : PageView.builder(
                        onPageChanged: (i) => setState(() => _photoIndex = i),
                        itemCount: images.length,
                        itemBuilder: (context, i) => CachedNetworkImage(
                          imageUrl: images[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$price DA',
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        if (stock > 0 && stock <= 15)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('Only $stock left',
                                style: const TextStyle(
                                    color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),

                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _TrustBadge(icon: Icons.payments_outlined, label: 'Pay on delivery'),
                        _TrustBadge(icon: Icons.local_shipping_outlined, label: 'All 58 wilayas'),
                        _TrustBadge(icon: Icons.verified_outlined, label: 'Confirmed by call'),
                      ],
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                    ],

                    const SizedBox(height: 8),
                    Text(stock > 0 ? '$stock in stock' : 'Out of stock',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),

                    const SizedBox(height: 28),

                    Center(
                      child: PrimaryButton(
                        label: stock > 0 ? 'Order Now -- Pay on Delivery' : 'Out of Stock',
                        onPressed: stock > 0
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
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