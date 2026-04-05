import 'package:flutter/material.dart';

/// Brand colors for memoir. Mobile Runner.
///
/// Light monochrome palette — putih, hitam, abu-abu.
/// Estetika receipt photobooth: bersih, luas, terang, premium.
class AppColors {
  AppColors._();

  // Brand
  static const Color brandPrimary = Color(0xFF000000);
  static const Color brandAccent = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFF9E9E9E);
  static const Color info = Color(0xFF757575);

  // Surfaces (light monochrome)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color surfaceContainer = Color(0xFFEEEEEE);

  // Text
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF777777);
  static const Color textDisabled = Color(0xFFBBBBBB);

  // Borders & dividers
  static const Color border = Color(0xFFDDDDDD);
  static const Color divider = Color(0xFFEEEEEE);
}
