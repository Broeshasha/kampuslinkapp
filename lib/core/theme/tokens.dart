import 'package:flutter/animation.dart';

/// Spacing scale (dp). Use these, never raw numbers, in screens.
abstract final class KSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

/// Corner radii (dp).
abstract final class KRadius {
  static const double chip = 12, button = 16, card = 20, sheet = 28;
}

/// Motion: short and ease-out. Respect "reduce motion" where used.
abstract final class KMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
}

/// Layout breakpoints (dp of available width).
/// compact < medium <= medium-layout < expanded <= expanded-layout.
abstract final class KBreakpoints {
  static const double medium = 600, expanded = 840, readingMaxWidth = 720;
}

/// 12 module accents (MASTER_PLAN 9). A module's colour = id mod 12.
const moduleAccents = <Color>[
  Color(0xFF3E7BFA),
  Color(0xFF2EC4B6),
  Color(0xFF2FA86B),
  Color(0xFFA3C93A),
  Color(0xFFE0A937),
  Color(0xFFF28C38),
  Color(0xFFE8604C),
  Color(0xFFE86AA6),
  Color(0xFFB07CF0),
  Color(0xFF7C8CF8),
  Color(0xFF38BDF8),
  Color(0xFF9AA5B1),
];

Color moduleAccent(int moduleId) =>
    moduleAccents[moduleId.abs() % moduleAccents.length];
