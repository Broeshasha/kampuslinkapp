import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';

/// Keeps reading content at a comfortable width on tablets and web,
/// centred; on phones it simply fills the width.
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.maxWidth = KBreakpoints.readingMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
