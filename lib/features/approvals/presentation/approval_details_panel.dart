import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/approval_details.dart';

String formatApprovalMoney(String raw) {
  final n = double.tryParse(raw);
  if (n == null) return raw;
  if (n == n.roundToDouble()) {
    return formatGroupedNumber(n, fractionDigits: 0);
  }
  return formatGroupedNumber(n);
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
                      child: fact.kind == 'notes'
                          ? _NotesFactRow(notes: fact.value)
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    fact.label,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.mutedForeground,
                                        ),
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

class _NotesFactRow extends StatelessWidget {
  const _NotesFactRow({required this.notes});

  final String notes;

  Future<void> _open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Notes',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      notes,
                      style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: InkWell(
        key: const Key('approval_view_notes'),
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.notes_outlined, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to view full notes',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
