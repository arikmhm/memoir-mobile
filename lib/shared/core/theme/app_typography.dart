import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for memoir. Mobile Runner.
///
/// Uses Google Fonts Inter per PRD-05 Section 9.3.
/// Minimum 16sp body, 24sp+ headings per PRD UI guidelines.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      // Display
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),

      // Headline (≥24sp per PRD)
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),

      // Title
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),

      // Body (≥16sp per PRD)
      bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),

      // Label
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );
}
