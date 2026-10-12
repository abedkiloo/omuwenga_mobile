import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Plus Jakarta Sans — modern, calm, high legibility (not Inter/Roboto).
abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  static TextTheme textTheme({bool fetchRuntimeFonts = true}) {
    // Tests / offline CI: never hit the network for font bytes.
    final useRuntime = fetchRuntimeFonts && GoogleFonts.config.allowRuntimeFetching;
    final TextTheme base = useRuntime
        ? GoogleFonts.plusJakartaSansTextTheme().apply(
            bodyColor: AppColors.foreground,
            displayColor: AppColors.foreground,
          )
        : ThemeData.light().textTheme.apply(
            fontFamily: fontFamily,
            bodyColor: AppColors.foreground,
            displayColor: AppColors.foreground,
          );
    return _scale(base);
  }

  /// Heavy all-caps brand wordmark (cue: OMUWENGA).
  static TextStyle brandWordmark({double fontSize = 28}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.4,
      color: AppColors.primary,
      height: 1.1,
    );
  }

  /// Label (softer) vs value (bold navy) — cue info chunks.
  static TextStyle infoLabel(TextTheme theme) =>
      (theme.labelMedium ?? const TextStyle()).copyWith(
        color: AppColors.accent,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      );

  static TextStyle infoValue(TextTheme theme) =>
      (theme.titleMedium ?? const TextStyle()).copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      );

  static TextTheme _scale(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.accent,
      ),
    );
  }
}
