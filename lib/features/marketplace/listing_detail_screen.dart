import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/report_dialog.dart';
import '../messages/chat_screen.dart';

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
    final sellerId = widget.listing['seller_id'];
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyListing = sellerId != null && sellerId == myId;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => ReportDialog.show(
              context: context,
              targetType: 'listing',
              targetId: widget.listing['id'],
            ),
          ),
        ],
      ),
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

                // Never show "Message seller" on your own listing.
                if (!isMyListing)
                  Center(
                    child: PrimaryButton(
                      label: 'Message seller',
                      onPressed: () async {
                        final seller = await Supabase.instance.client
                            .from('profiles')
                            .select('username, avatar_url, avatar_blurhash')
                            .eq('id', sellerId)
                            .single();

                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: sellerId,
                                otherUsername: seller['username'],
                                otherAvatarUrl: seller['avatar_url'],
                                otherAvatarBlurhash: seller['avatar_blurhash'],
                                initialListingId: widget.listing['id'],
                              ),
                            ),
                          );
                        }
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