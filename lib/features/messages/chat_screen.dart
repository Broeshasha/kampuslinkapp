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
  final Map<String, Map<String, dynamic>> _listingCache = {};
  bool _loading = true;
  bool _sending = false;
  bool _isFirstContact = true;

  // The listing attached to the NEXT message about to be sent —
  // shown as a WhatsApp-style reply preview above the composer,
  // cleared after that one message is sent (or dismissed by the user).
  Map<String, dynamic>? _pendingListing;

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

      // Fetch details for every distinct listing referenced anywhere
      // in this thread, so each message can show its own attached card.
      final listingIds = messages
          .map((m) => m['listing_id'])
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      if (listingIds.isNotEmpty) {
        final listings = await _supabase
            .from('marketplace_listings')
            .select('id, title, price_dzd, image_urls')
            .inFilter('id', listingIds);
        for (final l in listings) {
          _listingCache[l['id']] = l;
        }
      }

      final isFirstContact = messages.isEmpty;

      // On first contact via "Message seller": pre-fill the composer
      // and show the listing as a pending attachment, exactly once.
      if (isFirstContact && widget.initialListingId != null) {
        Map<String, dynamic>? listing = _listingCache[widget.initialListingId];
        listing ??= await _supabase
            .from('marketplace_listings')
            .select('id, title, price_dzd, image_urls')
            .eq('id', widget.initialListingId!)
            .maybeSingle();

        if (listing != null) {
          _listingCache[listing['id']] = listing;
          _pendingListing = listing;
          _controller.text = 'Is this still available?';
        }
      }

      setState(() {
        _messages = messages;
        _isFirstContact = isFirstContact;
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
    final attachedListingId = _pendingListing?['id'];
    _controller.clear();
    try {
      await _supabase.from('messages').insert({
        'sender_id': userId,
        'recipient_id': widget.otherUserId,
        'content': content,
        'listing_id': attachedListingId,
      });
      setState(() => _pendingListing = null); // attach once, like WhatsApp's reply preview
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

  void _openListing(Map<String, dynamic> listing) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)),
    );
  }

  Widget _listingChip(Map<String, dynamic> listing, {VoidCallback? onDismiss}) {
    final images = List<String>.from(listing['image_urls'] ?? []);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Row(
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 32, height: 32,
                child: BlurHashImage(imageUrl: images.first),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(listing['title'],
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${listing['price_dzd']} DA',
                    style: const TextStyle(color: AppColors.accent, fontSize: 11)),
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ),
        ],
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
                        final listing = m['listing_id'] != null ? _listingCache[m['listing_id']] : null;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.accent : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Quoted listing attached to THIS specific
                                // message — WhatsApp reply-style, not a
                                // thread-wide banner.
                                if (listing != null)
                                  GestureDetector(
                                    onTap: () => _openListing(listing),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _listingChip(listing),
                                    ),
                                  ),
                                Text(m['content'], style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Pending listing preview — sits above the composer,
                // dismissible, attaches to the next message only.
                if (_pendingListing != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: _listingChip(
                      _pendingListing!,
                      onDismiss: () => setState(() => _pendingListing = null),
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