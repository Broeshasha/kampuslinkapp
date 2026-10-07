import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/searchable_picker.dart';
import '../../core/config/dropdz_locations_service.dart';

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
  final _addressController = TextEditingController();
  int _quantity = 1;
  bool _submitting = false;

  Wilaya? _selectedWilaya;
  Commune? _selectedCommune;
  List<Wilaya> _wilayas = [];
  bool _loadingWilayas = true;
  bool _loadingCommunes = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadWilayas();
  }

  Future<void> _loadWilayas() async {
    setState(() {
      _loadingWilayas = true;
      _locationError = null;
    });
    try {
      final wilayas = await DropdzLocationsService.getWilayas();
      if (!mounted) return;
      setState(() {
        _wilayas = wilayas;
        _loadingWilayas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWilayas = false;
        _locationError = 'Could not load wilayas. Check your connection and try again.';
      });
    }
  }

  Future<void> _pickWilaya() async {
    if (_wilayas.isEmpty) return;
    final picked = await SearchablePicker.show<Wilaya>(
      context: context,
      title: 'Select your wilaya',
      items: _wilayas,
      labelBuilder: (w) => w.name,
    );
    if (picked == null) return;

    setState(() {
      _selectedWilaya = picked;
      _selectedCommune = null;
      _loadingCommunes = true;
    });

    try {
      await DropdzLocationsService.getCommunes(picked.id);
    } finally {
      if (mounted) setState(() => _loadingCommunes = false);
    }
  }

  Future<void> _pickCommune() async {
    if (_selectedWilaya == null) return;
    List<Commune> communes;
    try {
      communes = await DropdzLocationsService.getCommunes(_selectedWilaya!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load communes for that wilaya.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final picked = await SearchablePicker.show<Commune>(
      context: context,
      title: 'Select your commune',
      items: communes,
      labelBuilder: (c) => c.name,
    );
    if (picked == null) return;

    setState(() => _selectedCommune = picked);

    // Prefill the address field with "Commune, Wilaya" so the person only
    // has to add street/building detail -- same convenience as location-picker
    // apps like InDrive, without needing GPS or a map.
    if (_addressController.text.trim().isEmpty && _selectedWilaya != null) {
      _addressController.text = '${picked.name}, ${_selectedWilaya!.name}, ';
      _addressController.selection = TextSelection.fromPosition(
        TextPosition(offset: _addressController.text.length),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWilaya == null || _selectedCommune == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your wilaya and commune.')),
      );
      return;
    }

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
        'buyer_wilaya': _selectedWilaya!.name,
        'buyer_commune': _selectedCommune!.name,
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
                  ..pop()
                  ..pop();
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

  Widget _pickerField({
    required String label,
    required String? value,
    required bool loading,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  color: value != null ? Colors.white : AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              )
            else
              Icon(Icons.arrow_drop_down,
                  color: enabled ? AppColors.textSecondary : AppColors.border),
          ],
        ),
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

                if (_locationError != null) ...[
                  Text(_locationError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextButton(onPressed: _loadWilayas, child: const Text('Retry')),
                  const SizedBox(height: 6),
                ] else if (_loadingWilayas) ...[
                  const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  const SizedBox(height: 12),
                ] else ...[
                  _pickerField(
                    label: 'Select wilaya',
                    value: _selectedWilaya == null
                        ? null
                        : _selectedWilaya!.name,
                    loading: false,
                    enabled: true,
                    onTap: _pickWilaya,
                  ),
                  const SizedBox(height: 12),
                  _pickerField(
                    label: _selectedWilaya == null ? 'Select wilaya first' : 'Select commune',
                    value: _selectedCommune?.name,
                    loading: _loadingCommunes,
                    enabled: _selectedWilaya != null,
                    onTap: _pickCommune,
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: _fieldDecoration('Street / building / landmark'),
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