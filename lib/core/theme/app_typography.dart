import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale. Family target: Plus Jakarta Sans (bundle assets in a later
/// sprint). Until then we use an explicit family name so Material falls back
/// cleanly in tests and offline CI without runtime font fetching.
abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  static TextTheme textTheme({bool fetchRuntimeFonts = true}) {
    // fetchRuntimeFonts reserved for future bundled/google_fonts wiring.
    // Keeping the parameter preserves AppTheme.call sites from S01.
    final base = ThemeData.light().textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    );
    return _scale(base);
  }

  static TextTheme _scale(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      labelLarge: base.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}
