import 'package:flutter/material.dart';

/// Field-ops design tokens (visit order mocks + shared mobile chrome).
abstract final class AppColors {
  static const Color background = Color(0xFFF4F6F8);
  static const Color foreground = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0B1F33);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFE8EEF5);
  static const Color accentSoft = Color(0xFFE8EEF5);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color destructive = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color online = success;
  static const Color warning = Color(0xFFF59E0B);
  static const Color border = Color(0xFFE5EAF0);
  static const double radius = 12;

  /// Legacy brand green — use for success/standing, not primary CTAs.
  static const Color brandGreen = Color(0xFF1E9E4B);

  static Color starTone(String tone) {
    switch (tone) {
      case 'gold':
        return const Color(0xFFF59E0B);
      case 'teal':
        return const Color(0xFF0D9488);
      case 'emerald':
        return const Color(0xFF059669);
      case 'amber':
        return const Color(0xFFD97706);
      case 'orange':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFE11D48);
    }
  }

  static List<Color> starGradient(String tone) {
    switch (tone) {
      case 'gold':
        return const [Color(0xFFF59E0B), Color(0xFFFDE68A)];
      case 'teal':
        return const [Color(0xFF0D9488), Color(0xFF5EEAD4)];
      case 'emerald':
        return const [Color(0xFF059669), Color(0xFF6EE7B7)];
      case 'amber':
        return const [Color(0xFFD97706), Color(0xFFFCD34D)];
      case 'orange':
        return const [Color(0xFFEA580C), Color(0xFFFDBA74)];
      default:
        return const [Color(0xFFE11D48), Color(0xFFFB7185)];
    }
  }
}
