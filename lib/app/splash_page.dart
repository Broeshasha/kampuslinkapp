import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../ui/brand_logo.dart';

/// Shown only while the app checks whether onboarding is done (signed in,
/// nothing remembered yet, waiting for get_me()).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(animate: false),
            SizedBox(height: KSpace.xl),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
