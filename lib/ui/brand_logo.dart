import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// KampusLink mark: gradient tile with a soft brand glow. Pops in gently
/// (instantly when the phone asks for reduced motion).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96, this.animate = true});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kc.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: kc.accent.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(Icons.school_rounded, color: kc.onAccent, size: size * 0.55),
    );
    if (!animate || MediaQuery.disableAnimationsOf(context)) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
      child: logo,
    );
  }
}
