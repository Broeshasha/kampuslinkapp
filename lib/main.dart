import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

/// WP1 purge: empty shell. The real bootstrap (Firebase, Supabase, Drift,
/// Riverpod, router, l10n) arrives in WP2.
void main() {
  runApp(const KampusLinkApp());
}

class KampusLinkApp extends StatelessWidget {
  const KampusLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KampusLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Center(
          child: Text(
            'KampusLink',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
