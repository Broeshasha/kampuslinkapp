import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A continuously auto-scrolling strip banner. No external package needed —
/// just a Timer nudging a ScrollController forward and wrapping to 0.
class DeliveryMarqueeBanner extends StatefulWidget {
  const DeliveryMarqueeBanner({super.key});

  @override
  State<DeliveryMarqueeBanner> createState() => _DeliveryMarqueeBannerState();
}

class _DeliveryMarqueeBannerState extends State<DeliveryMarqueeBanner> {
  final _scrollController = ScrollController();
  Timer? _timer;
  double _offset = 0;

  static const _items = [
    ('local_shipping', 'Delivered to all 58 wilayas'),
    ('payments', 'Pay on delivery — no online payment needed'),
    ('verified', 'Every order confirmed by call before shipping'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      _offset += 0.6;
      if (_offset >= maxExtent) _offset = 0;
      _scrollController.jumpTo(_offset);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _chip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static const _icons = {
    'local_shipping': Icons.local_shipping_outlined,
    'payments': Icons.payments_outlined,
    'verified': Icons.verified_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surface,
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Repeat the sequence several times so the wrap-to-zero jump is invisible.
          for (int rep = 0; rep < 4; rep++)
            ..._items.map((item) => _chip(_icons[item.$1]!, item.$2)),
        ],
      ),
    );
  }
}