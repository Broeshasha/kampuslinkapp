import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class KampusStoreOrdersScreen extends StatefulWidget {
  const KampusStoreOrdersScreen({super.key});

  @override
  State<KampusStoreOrdersScreen> createState() => _KampusStoreOrdersScreenState();
}

class _KampusStoreOrdersScreenState extends State<KampusStoreOrdersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _orders = [];
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
          .from('pending_kampus_store_orders')
          .select()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Admin orders load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _callBuyer(String orderId, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _markStatus(orderId, 'called');
    }
  }

  Future<void> _whatsappBuyer(String phone) async {
    final normalized = phone.startsWith('0') ? '+213${phone.substring(1)}' : phone;
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markStatus(String orderId, String status, {String? notes}) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('kampus_store_orders').update({
      'status': status,
      'called_at': DateTime.now().toIso8601String(),
      'called_by': userId,
      if (notes != null) 'call_notes': notes,
    }).eq('id', orderId);

    await _supabase.from('kampus_store_order_events').insert({
      'order_id': orderId,
      'event_type': status,
      'detail': {'notes': notes},
    });

    _load();
  }

  void _showNotesDialog(String orderId, String targetStatus) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          targetStatus == 'confirmed_by_call' ? 'Confirm order' : 'Cancel order',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Notes (optional) -- size, address change, etc.',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _markStatus(orderId, targetStatus, notes: controller.text);
            },
            child: Text(
              targetStatus == 'confirmed_by_call' ? 'Confirm' : 'Cancel order',
              style: TextStyle(
                color: targetStatus == 'confirmed_by_call' ? AppColors.accent : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kampus Store -- Incoming Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text('No pending orders.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, i) => _orderCard(_orders[i]),
                    ),
            ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final isPending = o['status'] == 'pending_call';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o['buyer_full_name'] ?? '--',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Wants: ${o['product_display_name'] ?? '--'} (x${o['quantity']})',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text('${o['sell_price']} DA',
              style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${o['buyer_wilaya']} -- ${o['buyer_commune']}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(o['buyer_address'] ?? '',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(o['buyer_phone'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: isPending
                ? [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.call, size: 17),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: () => _callBuyer(o['id'], o['buyer_phone']),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chat, size: 17),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                      onPressed: () => _whatsappBuyer(o['buyer_phone']),
                    ),
                  ]
                : [
                    OutlinedButton(
                      onPressed: () => _showNotesDialog(o['id'], 'confirmed_by_call'),
                      child: const Text('Confirm'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => _showNotesDialog(o['id'], 'cancelled'),
                      child: const Text('Cancel'),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}