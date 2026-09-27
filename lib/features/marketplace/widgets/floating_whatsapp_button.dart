import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Floating WhatsApp button with a subtle pulsing ring behind it, so it
/// actually catches the eye instead of sitting flat like a generic FAB.
/// Drop into a Stack: Stack(children: [..., FloatingWhatsAppButton(phoneNumber: '213...')])
class FloatingWhatsAppButton extends StatefulWidget {
  final String phoneNumber;
  final String prefilledMessage;

  const FloatingWhatsAppButton({
    super.key,
    required this.phoneNumber,
    this.prefilledMessage = "Hi, I have a question about a product on Kampus Store",
  });

  @override
  State<FloatingWhatsAppButton> createState() => _FloatingWhatsAppButtonState();
}

class _FloatingWhatsAppButtonState extends State<FloatingWhatsAppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  static const _whatsappGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/${widget.phoneNumber}?text=${Uri.encodeComponent(widget.prefilledMessage)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: _openWhatsApp,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing ring, expands and fades out on loop
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final t = _pulseController.value;
                  return Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
                    child: Transform.scale(
                      scale: 0.7 + (t * 0.6),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _whatsappGreen,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // The actual button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _whatsappGreen,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}