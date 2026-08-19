import 'package:flutter/material.dart';

/// Wraps any standalone screen's content so it's centered and width-capped
/// on tablet/desktop, and full-width (as designed) on mobile.
/// Use this around every standalone screen — onboarding, auth, etc.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}