import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/approval_details.dart';

String formatApprovalMoney(String raw) {
  final n = double.tryParse(raw);
  if (n == null) return raw;
  if (n == n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toStringAsFixed(2);
}

/// Renders API approval sections (facts + line items) for the checker.
class ApprovalDetailsPanel extends StatelessWidget {
  const ApprovalDetailsPanel({super.key, required this.details});

  final ApprovalDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return Text(
        'No extra details were provided for this request.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.mutedForeground,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in details.sections) ...[
          Text(
            section.title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          if (section.facts.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.secondary,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  for (final fact in section.facts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              fact.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedForeground),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              fact.kind == 'money'
                                  ? 'KES ${formatApprovalMoney(fact.value)}'
                                  : fact.value,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (section.lines.isNotEmpty) ...[
            if (section.facts.isNotEmpty) const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < section.lines.length; i++)
                    Container(
                      key: Key('approval_line_$i'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(
                                top: BorderSide(color: AppColors.border),
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.lines[i].name,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (section.lines[i].variant.isNotEmpty)
                                  Text(
                                    section.lines[i].variant,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.mutedForeground,
                                        ),
                                  ),
                                Text(
                                  'Qty ${section.lines[i].quantity} × KES ${formatApprovalMoney(section.lines[i].unitPrice)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'KES ${formatApprovalMoney(section.lines[i].subtotal)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
