import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'kampus_store_product_screen.dart';
import 'widgets/delivery_marquee_banner.dart';
import 'widgets/whatsapp_question_bar.dart';
import 'widgets/floating_whatsapp_button.dart';

// TODO: put your real KampusLink WhatsApp business number here,
// international format, no + or spaces, e.g. '213555123456'
const String kKampusStoreWhatsAppNumber = '213551757401';

class KampusStoreScreen extends StatefulWidget {
  const KampusStoreScreen({super.key});

  @override
  State<KampusStoreScreen> createState() => _KampusStoreScreenState();
}

class _KampusStoreScreenState extends State<KampusStoreScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('kampus_store_products')
          .select()
          .eq('is_active', true)
          .order('category')
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const WhatsAppQuestionBar(phoneNumber: kKampusStoreWhatsAppNumber),
            const DeliveryMarqueeBanner(),
            Expanded(child: _body()),
          ],
        ),
        const FloatingWhatsAppButton(phoneNumber: kKampusStoreWhatsAppNumber),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text('No products available right now.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _products.length,
        itemBuilder: (context, i) => _productCard(_products[i]),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final images = List<String>.from(product['images'] ?? []);
    final imageUrl = images.isNotEmpty ? images.first : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KampusStoreProductScreen(product: product)),
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
            Expanded(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: AppColors.border),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.border,
                        child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary),
                      ),
                    )
                  : Container(color: AppColors.border),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${product['sell_price']} DA',
                      style: const TextStyle(
                          color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(product['display_name'] ?? '',
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