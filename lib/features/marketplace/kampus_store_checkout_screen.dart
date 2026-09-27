import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class KampusStoreCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const KampusStoreCheckoutScreen({super.key, required this.product});

  @override
  State<KampusStoreCheckoutScreen> createState() => _KampusStoreCheckoutScreenState();
}

class _KampusStoreCheckoutScreenState extends State<KampusStoreCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _wilayaController = TextEditingController();
  final _communeController = TextEditingController();
  final _addressController = TextEditingController();
  int _quantity = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _wilayaController.dispose();
    _communeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      await supabase.from('kampus_store_orders').insert({
        'student_id': userId,
        'product_id': widget.product['id'],
        'quantity': _quantity,
        'buyer_full_name': _nameController.text.trim(),
        'buyer_phone': _phoneController.text.trim(),
        'buyer_wilaya': _wilayaController.text.trim(),
        'buyer_commune': _communeController.text.trim(),
        'buyer_address': _addressController.text.trim(),
        'status': 'pending_call',
      });

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Order placed!', style: TextStyle(color: Colors.white)),
          content: const Text(
            "We'll call or WhatsApp you shortly to confirm your order before shipping.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context)
                  ..pop() // close product detail
                  ..pop(); // close product screen back to grid
              },
              child: const Text('OK', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.product['sell_price'] as num) * _quantity;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.product['display_name'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          Text('$_quantity', style: const TextStyle(color: Colors.white)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('Total: $total DA',
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Phone number (WhatsApp)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _wilayaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Wilaya'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _communeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Commune'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: _fieldDecoration('Full address'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Place Order (Cash on Delivery)',
                  loading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                const Text(
                  "We'll call or WhatsApp you to confirm before your order ships.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}