import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Soft blue reminder strip — gentle nudge, not alarmist urgency.
class CbReminderBanner extends StatelessWidget {
  const CbReminderBanner({
    super.key,
    required this.message,
    this.icon = Icons.check_circle_outline_rounded,
    this.margin,
  });

  final String message;
  final IconData icon;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.reminder,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.reminderForeground,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
