import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Side-by-side scannable fact cell (Date / Deadline cue pattern).
class CbInfoChunk extends StatelessWidget {
  const CbInfoChunk({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTypography.infoLabel(textTheme)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.infoValue(textTheme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!expanded) return child;
    return Expanded(child: child);
  }
}

/// Two equal info chunks in one row (cue date + deadline).
class CbInfoChunkRow extends StatelessWidget {
  const CbInfoChunkRow({
    super.key,
    required this.left,
    required this.right,
    this.gap = 10,
  });

  final CbInfoChunk left;
  final CbInfoChunk right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        left,
        SizedBox(width: gap),
        right,
      ],
    );
  }
}
