import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../buttons/cb_primary_button.dart';

class CbStickyActionBar extends StatelessWidget {
  const CbStickyActionBar({
    super.key,
    this.summary,
    this.summaryTrailing,
    this.primaryLabel = 'Continue',
    this.onPrimary,
    this.primaryKey,
    this.child,
    this.secondary,
  });

  final String? summary;
  final String? summaryTrailing;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key? primaryKey;
  final Widget? child;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: const Color(0x1A0F172A),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null || summaryTrailing != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      if (summary != null)
                        Expanded(
                          child: Text(
                            summary!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                        ),
                      if (summaryTrailing != null)
                        Text(
                          summaryTrailing!,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              if (secondary != null) ...[secondary!, const SizedBox(height: 4)],
              child ??
                  CbPrimaryButton(
                    key: primaryKey,
                    label: primaryLabel,
                    onPressed: onPrimary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
