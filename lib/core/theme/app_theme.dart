import 'package:flutter/material.dart';

class AppColors {
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

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }
}