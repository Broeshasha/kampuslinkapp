import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton_loader.dart';
import 'kampus_store_product_screen.dart';
import 'widgets/delivery_marquee_banner.dart';
import 'widgets/whatsapp_question_bar.dart';
import 'widgets/floating_whatsapp_button.dart';

// TODO: put your real KampusLink WhatsApp business number here,
// international format, no + or spaces, e.g. '213555123456'
const String kKampusStoreWhatsAppNumber = '213000000000';

class KampusStoreScreen extends StatefulWidget {
  const KampusStoreScreen({super.key});

  @override
  State<KampusStoreScreen> createState() => _KampusStoreScreenState();
}

class _KampusStoreScreenState extends State<KampusStoreScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _allProducts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint('Kampus Store load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allProducts;
      } else {
        _filtered = _allProducts.where((p) {
          final name = (p['display_name'] ?? '').toString().toLowerCase();
          final category = (p['category'] ?? '').toString().toLowerCase();
          final desc = (p['display_description'] ?? '').toString().toLowerCase();
          return name.contains(query) || category.contains(query) || desc.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const WhatsAppQuestionBar(phoneNumber: kKampusStoreWhatsAppNumber),
            const DeliveryMarqueeBanner(),
            _searchBar(),
            Expanded(child: _body()),
          ],
        ),
        const FloatingWhatsAppButton(phoneNumber: kKampusStoreWhatsAppNumber),
      ],
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (context, i) => SkeletonBox(height: double.infinity, borderRadius: BorderRadius.circular(14)),
      );
    }

    if (_filtered.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 200),
            Center(
              child: Text(
                _allProducts.isEmpty ? 'No products available right now.' : 'No results for that search.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _productCard(_filtered[i]),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final images = (product['images'] is List) ? List<String>.from(product['images']) : <String>[];
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
                      placeholder: (_, __) => const SkeletonBox(height: double.infinity),
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