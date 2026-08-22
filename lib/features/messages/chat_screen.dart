import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blurhash_image.dart';
import '../../core/widgets/report_dialog.dart';
import '../../core/config/block_service.dart';
import '../marketplace/listing_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? otherAvatarBlurhash;
  final String? initialListingId; // set when opened via "Message seller"

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.otherAvatarBlurhash,
    this.initialListingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = []; // newest first
  Map<String, dynamic>? _referencedListing;
  bool _loading = true;
  bool _sending = false;
  bool _isFirstContact = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$userId,recipient_id.eq.${widget.otherUserId}),'
              'and(sender_id.eq.${widget.otherUserId},recipient_id.eq.$userId)')
          .order('created_at', ascending: false); // newest first, for reverse:true

      final messages = List<Map<String, dynamic>>.from(data);

      final unreadIds = messages
          .where((m) => m['recipient_id'] == userId && m['read_at'] == null)
          .map((m) => m['id'])
          .toList();
      if (unreadIds.isNotEmpty) {
        await _supabase.from('messages').update({'read_at': DateTime.now().toIso8601String()})
            .inFilter('id', unreadIds);
      }

      // Referenced listing = most recent listing_id in this thread,
      // falling back to the one passed in when opened from a listing.
      final listingId = messages.firstWhere(
            (m) => m['listing_id'] != null,
            orElse: () => {'listing_id': widget.initialListingId},
          )['listing_id'] ??
          widget.initialListingId;

      Map<String, dynamic>? listing;
      if (listingId != null) {
        listing = await _supabase
            .from('marketplace_listings')
            .select('id, title, price_dzd, image_urls')
            .eq('id', listingId)
            .maybeSingle();
      }

      setState(() {
        _messages = messages;
        _isFirstContact = messages.isEmpty;
        _referencedListing = listing;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Chat load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final userId = _supabase.auth.currentUser!.id;
    _controller.clear();
    try {
      await _supabase.from('messages').insert({
        'sender_id': userId,
        'recipient_id': widget.otherUserId,
        'content': content,
        'listing_id': widget.initialListingId ?? _referencedListing?['id'],
      });
      await _load();
    } catch (e) {
      debugPrint('Send message error: $e');
    }
    setState(() => _sending = false);
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.danger),
              title: const Text('Block user', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(context);
                final blocked = await BlockService.blockUser(context, widget.otherUserId);
                if (blocked && mounted) Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
              title: const Text('Report', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                ReportDialog.show(context: context, targetType: 'user', targetId: widget.otherUserId);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 30, height: 30,
                child: widget.otherAvatarUrl != null
                    ? BlurHashImage(
                        imageUrl: widget.otherAvatarUrl!,
                        blurhash: widget.otherAvatarBlurhash,
                      )
                    : Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Text('@${widget.otherUsername}'),
          ],
        ),
        actions: [
          IconButton(onPressed: _showMenu, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                if (_referencedListing != null)
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listing: _referencedListing!)),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 36, height: 36,
                              child: BlurHashImage(
                                imageUrl: List<String>.from(_referencedListing!['image_urls']).first,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_referencedListing!['title'],
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                                Text('${_referencedListing!['price_dzd']} DA',
                                    style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
                        ],
                      ),
                    ),
                  ),
                if (_isFirstContact)
                  Container(
                    width: double.infinity,
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Text(
                      "You don't know this person yet — be cautious sharing personal details.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _load,
                    child: ListView.builder(
                      reverse: true, // pins to newest message, no manual scroll code needed
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final isMe = m['sender_id'] == userId;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.accent : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(m['content'], style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                            : const Icon(Icons.send, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}