import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/primary_button.dart';

class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> listing;
  const ListingDetailScreen({super.key, required this.listing});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(widget.listing['image_urls']);
    final blurhashes = List<String>.from(widget.listing['image_blurhashes'] ?? []);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              onPageChanged: (i) => setState(() => _photoIndex = i),
              itemCount: images.length,
              itemBuilder: (context, i) => BlurHashImage(
                imageUrl: images[i],
                blurhash: i < blurhashes.length ? blurhashes[i] : null,
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
                  width: 6, height: 6,
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
                Text('${widget.listing['price_dzd']} DA',
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(widget.listing['title'],
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                if ((widget.listing['description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(widget.listing['description'],
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                ],
                const SizedBox(height: 28),
                Center(
                  child: PrimaryButton(
                    label: 'Message seller',
                    onPressed: () {
                      // Messages screen isn't built yet — this wires in
                      // once that exists, same as the plan's build order.
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}