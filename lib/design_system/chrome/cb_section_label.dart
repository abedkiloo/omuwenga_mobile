import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CbSectionLabel extends StatelessWidget {
  const CbSectionLabel({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.mutedForeground,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisSize: constraints.hasBoundedWidth
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.mutedForeground),
              const SizedBox(width: 6),
            ],
            if (constraints.hasBoundedWidth) Flexible(child: text) else text,
          ],
        );
      },
    );
  }
}
