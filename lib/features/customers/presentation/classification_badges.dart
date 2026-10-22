import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/customer_intelligence.dart';

/// Compact classification chips with long-press / tooltip explanations.
class ClassificationBadges extends StatelessWidget {
  const ClassificationBadges({
    super.key,
    required this.engagementTier,
    this.buyerSegment = BuyerSegment.any,
    this.purchaseCount = 0,
    this.showPurchaseCount = false,
    this.compact = true,
  });

  final EngagementTier engagementTier;
  final BuyerSegment buyerSegment;
  final int purchaseCount;
  final bool showPurchaseCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tierLabel = engagementTier.badgeLabel;
    if (tierLabel.isEmpty) return const SizedBox.shrink();

    final showSegment =
        engagementTier == EngagementTier.buyer &&
        buyerSegment != BuyerSegment.any;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TipChip(
          label: tierLabel,
          tip: engagementTier.badgeTip,
          filled: engagementTier == EngagementTier.buyer,
          compact: compact,
        ),
        if (showSegment)
          _TipChip(
            label: buyerSegment.label,
            tip: buyerSegment.badgeTip,
            filled: false,
            compact: compact,
          ),
        if (showPurchaseCount &&
            engagementTier == EngagementTier.buyer &&
            purchaseCount > 0)
          Text(
            formatPurchaseCount(purchaseCount),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
              fontSize: compact ? 10 : 12,
            ),
          ),
      ],
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.tip,
    required this.filled,
    required this.compact,
  });

  final String label;
  final String tip;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.secondary;
    final fg = filled ? AppColors.primaryForeground : AppColors.mutedForeground;
    final border = filled ? AppColors.primary : AppColors.border;

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 10 : 12,
          ),
        ),
      ),
    );
  }
}
