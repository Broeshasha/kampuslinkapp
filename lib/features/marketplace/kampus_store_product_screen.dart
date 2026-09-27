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
    final images = List<String>.from(widget.product['images'] ?? []);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: images.isEmpty
                    ? Container(color: AppColors.border)
                    : PageView.builder(
                        onPageChanged: (i) => setState(() => _photoIndex = i),
                        itemCount: images.length,
                        itemBuilder: (context, i) => CachedNetworkImage(
                          imageUrl: images[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.border),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.border,
                            child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
              ),
              if (images.length > 1) ...[
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
              ],
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.product['sell_price']} DA',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(widget.product['display_name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    Text(widget.product['display_description'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('${widget.product['stock']} in stock',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrimaryButton(
            label: 'Order Now',
            icon: Icons.shopping_bag_outlined,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KampusStoreCheckoutScreen(product: widget.product),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}