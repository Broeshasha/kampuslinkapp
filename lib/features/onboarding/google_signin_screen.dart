import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/config/auth_service.dart';

class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      setState(() {
        _error = 'Error: $e'; // showing the real error temporarily, for debugging
        _loading = false;
      });
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.link_rounded, color: AppColors.accent, size: 32),
            ),
            const SizedBox(height: 24),
            const Text('Welcome to KampusLink',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Everything you need to navigate student life in Algeria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              label: _loading ? 'Signing in...' : 'Continue with Google',
              loading: _loading,
              onPressed: _handleSignIn,
              icon: Icons.g_mobiledata,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Terms',
                    style: const TextStyle(color: AppColors.accent),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _openLink('https://site.kampus-link.com/terms.html'),
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(color: AppColors.accent),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _openLink('https://site.kampus-link.com/privacy.html'),
                  ),
                  const TextSpan(text: ', and '),
                  TextSpan(
                    text: 'Community Guidelines',
                    style: const TextStyle(color: AppColors.accent),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          _openLink('https://site.kampus-link.com/community-guidelines.html'),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}