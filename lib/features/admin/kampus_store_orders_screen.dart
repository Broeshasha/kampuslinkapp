import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

// TODO: put your real order-submit Worker URL here once deployed
const String kOrderSubmitWorkerUrl = 'https://order-submit.chidafarai06.workers.dev';

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

  Future<void> _callBuyer(String orderId, String phone, String status) async {
    final uri = Uri(scheme: 'tel', path: phone);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) launched = await launchUrl(uri);
    } catch (_) {}

    if (!launched) {
      // e.g. Chrome on a computer has no dialer -- show the number instead.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No dialer on this device. Call manually: $phone')),
        );
      }
      return;
    }

    // Just bookkeeping -- the Call API button below no longer depends on this.
    if (status == 'pending_call') await _markStatus(orderId, 'called');
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

  /// Saves the call notes, then asks the order-submit Worker to send this
  /// order to DropDz. The order only leaves the inbox once DropDz has
  /// actually accepted it; if anything fails it stays here so you can retry.
  Future<void> _confirmAndSubmit(String orderId, String notes) async {
    final userId = _supabase.auth.currentUser?.id;

    try {
      await _supabase.from('kampus_store_orders').update({
        'call_notes': notes,
        'called_at': DateTime.now().toIso8601String(),
        'called_by': userId,
      }).eq('id', orderId);
    } catch (e) {
      debugPrint('Saving call notes failed (continuing anyway): $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitting to DropDz...')),
      );
    }

    try {
      final resp = await http
          .post(
            Uri.parse(kOrderSubmitWorkerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'orderId': orderId}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(resp.body);
      if (!mounted) return;

      if (resp.statusCode == 200 && data['ok'] == true) {
        final number = data['dropdzOrderNumber'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(number != null
                ? 'Sent to DropDz: $number'
                : 'Order was already sent to DropDz.'),
          ),
        );
      } else {
        final err = data['error'];
        final message = err is Map ? (err['message'] ?? err['error'] ?? err.toString()) : err;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DropDz rejected the order: ${message ?? 'unknown error'}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reach the order Worker: $e')),
        );
      }
    }

    _load();
  }

  void _showNotesDialog(String orderId, String targetStatus) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          targetStatus == 'confirmed_by_call' ? 'Send to DropDz' : 'Cancel order',
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
              if (targetStatus == 'confirmed_by_call') {
                _confirmAndSubmit(orderId, controller.text);
              } else {
                _markStatus(orderId, targetStatus, notes: controller.text);
              }
            },
            child: Text(
              targetStatus == 'confirmed_by_call' ? 'Send order' : 'Cancel order',
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
    final wasCalled = o['status'] == 'called';

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
          Row(
            children: [
              Expanded(
                child: Text(o['buyer_full_name'] ?? '--',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (wasCalled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Called',
                      style: TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
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
          if (o['referral_code'] != null && (o['referral_code'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Referral: ${o['referral_code']}',
                  style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.call, size: 17),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: () => _callBuyer(o['id'], o['buyer_phone'], o['status']),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat, size: 17),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                  onPressed: () => _whatsappBuyer(o['buyer_phone']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 17),
              label: const Text('Call API -- Send to DropDz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _showNotesDialog(o['id'], 'confirmed_by_call'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => _showNotesDialog(o['id'], 'cancelled'),
              child: const Text('Cancel order'),
            ),
          ),
        ],
      ),
    );
  }
}