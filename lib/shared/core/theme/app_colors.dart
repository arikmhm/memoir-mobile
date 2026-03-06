import 'package:flutter/material.dart';

/// Brand colors for memoir. Mobile Runner.
///
/// Uses `#1A1A2E` as seed color per PRD-05 Section 9.3.
/// Dark theme by default for kiosk usage.
class AppColors {
  AppColors._();

  // Brand
  static const Color brandPrimary = Color(0xFF1A1A2E);
  static const Color brandAccent = Color(0xFF16213E);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF42A5F5);

  // Surfaces (dark theme)
  static const Color surface = Color(0xFF121212);
  static const Color surfaceVariant = Color(0xFF1E1E2E);
  static const Color surfaceContainer = Color(0xFF2A2A3E);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDisabled = Color(0xFF666666);

  // Seed for Material 3 ColorScheme
  static const Color seedColor = brandPrimary;
}
