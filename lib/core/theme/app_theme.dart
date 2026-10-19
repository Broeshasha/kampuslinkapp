import 'package:flutter/material.dart';

import 'tokens.dart';

/// Brand reference (the dark identity). Screens do NOT use these directly:
/// they read `context.kc` so light and dark both work (D-011).
abstract final class AppColors {
  static const background = Color(0xFF0E0F11);
  static const surface = Color(0xFF17181B);
  static const border = Color(0xFF24262A);
  static const accent = Color(0xFF3E7BFA);
  static const textPrimary = Color(0xFFF2F3F5);
  static const textSecondary = Color(0xFFA6A9B0);
  static const official = Color(0xFF2FA86B);
  static const verified = Color(0xFF3E7BFA);
  static const community = Color(0xFFE0A937);
  static const danger = Color(0xFFD9534F);
}

/// Semantic colours for one brightness. Read with `context.kc`.
@immutable
class KampusColors extends ThemeExtension<KampusColors> {
  const KampusColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accentAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.official,
    required this.community,
    required this.danger,
    required this.success,
    required this.warning,
    required this.xp,
    required this.streak,
  });

  final Color background, surface, surfaceRaised, border;
  final Color accent, onAccent, accentText, accentAlt;
  final Color textPrimary, textSecondary;
  final Color official, community, danger, success, warning, xp, streak;

  static const dark = KampusColors(
    background: Color(0xFF0E0F11),
    surface: Color(0xFF17181B),
    surfaceRaised: Color(0xFF1F2024),
    border: Color(0xFF24262A),
    accent: Color(0xFF3E7BFA),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF6A98FB),
    accentAlt: Color(0xFF7C8CF8),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFFA6A9B0),
    official: Color(0xFF2FA86B),
    community: Color(0xFFE0A937),
    danger: Color(0xFFD9534F),
    success: Color(0xFF2FA86B),
    warning: Color(0xFFF28C38),
    xp: Color(0xFFE0A937),
    streak: Color(0xFFF28C38),
  );

  static const light = KampusColors(
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    border: Color(0xFFE2E4E8),
    accent: Color(0xFF2357D9),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF2357D9),
    accentAlt: Color(0xFF5B5BD6),
    textPrimary: Color(0xFF121317),
    textSecondary: Color(0xFF5A5F69),
    official: Color(0xFF1E7D4E),
    community: Color(0xFF8F6508),
    danger: Color(0xFFB83431),
    success: Color(0xFF1E7D4E),
    warning: Color(0xFFB4561A),
    xp: Color(0xFF8F6508),
    streak: Color(0xFFB4561A),
  );

  /// Accent to violet neighbour: primary buttons, streak, highlights.
  LinearGradient get accentGradient => LinearGradient(
    colors: [accent, accentAlt],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );

  @override
  KampusColors copyWith() => this;

  @override
  KampusColors lerp(ThemeExtension<KampusColors>? other, double t) {
    if (other is! KampusColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension KampusThemeX on BuildContext {
  KampusColors get kc =>
      Theme.of(this).extension<KampusColors>() ?? KampusColors.dark;
}

abstract final class AppTheme {
  static ThemeData get dark => _build(KampusColors.dark, Brightness.dark);
  static ThemeData get light => _build(KampusColors.light, Brightness.light);

  static ThemeData _build(KampusColors c, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.accent,
          brightness: brightness,
        ).copyWith(
          primary: c.accent,
          onPrimary: c.onAccent,
          secondary: c.accentAlt,
          surface: c.surface,
          onSurface: c.textPrimary,
          onSurfaceVariant: c.textSecondary,
          outline: c.border,
          outlineVariant: c.border,
          error: c.danger,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      dividerColor: c.border,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.card),
          side: BorderSide(color: c.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accent.withValues(alpha: 0.18),
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.button),
          ),
        ),
      ),
    );
  }
}
