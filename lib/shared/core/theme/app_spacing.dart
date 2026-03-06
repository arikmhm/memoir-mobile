/// Spacing tokens for consistent layout.
///
/// All values in logical pixels (dp).
/// Follows BLoC skill design system: zero hardcoded spacing values.
class AppSpacing {
  AppSpacing._();

  // Base scale
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Screen-level paddings
  static const double screenHorizontal = 24.0;
  static const double screenVertical = 16.0;

  // Touch target (Material Design minimum: 48dp)
  static const double touchTarget = 48.0;
}
