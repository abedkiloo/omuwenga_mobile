import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum CbStatusPillVariant { online, neutral, success, warning, info }

class CbStatusPill extends StatelessWidget {
  const CbStatusPill({
    super.key,
    required this.label,
    this.variant = CbStatusPillVariant.neutral,
    this.showOnlineDot = false,
  });

  final String label;
  final CbStatusPillVariant variant;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      CbStatusPillVariant.online => (
          const Color(0xFFDCFCE7),
          AppColors.success,
        ),
      CbStatusPillVariant.success => (
          const Color(0xFFDCFCE7),
          AppColors.success,
        ),
      CbStatusPillVariant.warning => (
          const Color(0xFFFEF3C7),
          AppColors.warning,
        ),
      CbStatusPillVariant.info => (AppColors.accentSoft, AppColors.primary),
      CbStatusPillVariant.neutral => (
          AppColors.secondary,
          AppColors.mutedForeground,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showOnlineDot || variant == CbStatusPillVariant.online) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
