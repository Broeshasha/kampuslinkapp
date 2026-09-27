import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-width bar at the very top of Kampus Store: "Have a question? Tap to
/// WhatsApp us." Tapping opens a WhatsApp chat directly.
class WhatsAppQuestionBar extends StatelessWidget {
  /// Full international number, no + or spaces. e.g. '213555123456'
  final String phoneNumber;

  const WhatsAppQuestionBar({super.key, required this.phoneNumber});

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent("Hi, I have a question about a product on Kampus Store")}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openWhatsApp,
      child: Container(
        width: double.infinity,
        color: const Color(0xFF25D366).withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chat, size: 15, color: Color(0xFF25D366)),
            SizedBox(width: 6),
            Text(
              'Have a question? Tap to WhatsApp us',
              style: TextStyle(color: Color(0xFF25D366), fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF25D366)),
          ],
        ),
      ),
    );
  }
}