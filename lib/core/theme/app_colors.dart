import 'package:flutter/material.dart';

/// Omuwenga design cue — trust navy, calm wash, chunked white cards.
///
/// Psychology: navy signals competence without alarm; soft blue reminders nudge
/// without cortisol spikes; large rounded cards + clear label/value hierarchy
/// cut cognitive load for cashiers under time pressure.
abstract final class AppColors {
  /// Soft blue-gray wash behind chrome (cue #F0F4F8).
  static const Color background = Color(0xFFF0F4F8);

  /// Near-black navy ink for body text.
  static const Color foreground = Color(0xFF0F1F33);

  /// White elevated surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  /// Brand / CTA navy (cue #0D2C54).
  static const Color primary = Color(0xFF0D2C54);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  /// Soft fill for chips, nav indicators, idle tiles.
  static const Color secondary = Color(0xFFE8EEF5);
  static const Color secondaryForeground = Color(0xFF0D2C54);

  /// Mid steel blue for icons / labels (cue #6B8EAD).
  static const Color accent = Color(0xFF6B8EAD);
  static const Color accentSoft = Color(0xFFE8EEF5);

  /// Reminder / callout wash.
  static const Color reminder = Color(0xFFDCE6F0);
  static const Color reminderForeground = Color(0xFF0D2C54);

  static const Color mutedForeground = Color(0xFF5B6B7C);

  /// True errors / voids only — not everyday urgency.
  static const Color destructive = Color(0xFFDC2626);
  static const Color success = Color(0xFF1E9E4B);
  static const Color online = success;
  static const Color warning = Color(0xFFD97706);

  static const Color border = Color(0xFFD7E0EA);

  /// Primary card radius (cue ~20–30).
  static const double radius = 22;

  /// Slightly tighter for chips / pills.
  static const double radiusSm = 14;

  /// Soft card elevation (navy-tinted, not harsh black).
  static const Color shadow = Color(0x140D2C54);

  /// Legacy brand green — success / standing only, never primary CTAs.
  static const Color brandGreen = Color(0xFF1E9E4B);

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: shadow,
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ];

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

  /// Dark tinted panel so star progress reads on the light app chrome.
  static Color starPanel(String tone) {
    switch (tone) {
      case 'gold':
        return const Color(0xFF1A1406);
      case 'teal':
        return const Color(0xFF041916);
      case 'emerald':
        return const Color(0xFF041A12);
      case 'amber':
        return const Color(0xFF1A1204);
      case 'orange':
        return const Color(0xFF1A0C04);
      default:
        return const Color(0xFF16060C);
    }
  }

  static Color onStar(String tone) {
    switch (tone) {
      case 'gold':
      case 'amber':
        return const Color(0xFF1A1200);
      default:
        return const Color(0xFFFFFFFF);
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
