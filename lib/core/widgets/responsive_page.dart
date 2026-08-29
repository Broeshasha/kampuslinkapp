import 'package:flutter/material.dart';

/// Wraps any standalone screen's content so it's centered and width-capped
/// on tablet/desktop, and full-width (as designed) on mobile.
/// Use this around every standalone screen -- onboarding, auth, etc.
/// NOTE: does not add scrolling itself -- screens whose content can run
/// long (long error text, small screens) should wrap their own content in
/// a SingleChildScrollView, the same way profile_setup_screen.dart already
/// does. Adding scroll here broke screens that nest a full Scaffold as
/// their child (Scaffold can't handle unbounded height from a scroll view).
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
