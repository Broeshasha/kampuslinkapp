import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../ui/max_width.dart';

/// Scrollable content + a fixed main button at the bottom (never hidden,
/// never overflowing, centred on tablets).
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.items,
    required this.action,
  });

  final List<Widget> items;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
            child: MaxWidth(maxWidth: 560, child: Column(children: items)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.xl,
            KSpace.sm,
            KSpace.xl,
            KSpace.lg,
          ),
          child: MaxWidth(
            maxWidth: 560,
            child: SizedBox(width: double.infinity, child: action),
          ),
        ),
      ],
    );
  }
}
