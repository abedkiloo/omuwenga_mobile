import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../domain/debt_management.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

class DebtCollectionsPanel extends StatelessWidget {
  const DebtCollectionsPanel({
    super.key,
    required this.date,
    required this.collections,
    required this.loading,
    this.error,
    this.showDateNav = true,
    this.onClose,
    this.onPreviousDay,
    this.onNextDay,
    this.onJumpToday,
    this.onOpenCustomer,
    this.onRetry,
  });

  final String date;
  final DebtCollections? collections;
  final bool loading;
  final String? error;
  final bool showDateNav;
  final VoidCallback? onClose;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;
  final VoidCallback? onJumpToday;
  final ValueChanged<DebtCollectionRow>? onOpenCustomer;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final today = localDateString();
    final nextDisabled = date.compareTo(today) >= 0;
    final count = collections?.count ?? collections?.results.length ?? 0;
    final total = collections?.total ?? 0;
    final rows = collections?.results ?? const <DebtCollectionRow>[];

    return CbSurfaceCard(
      key: const Key('debt_collections_panel'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collections',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Who paid, how much, and what remains on ${formatCollectionDateLabel(date)}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  key: const Key('debt_collections_close'),
                  tooltip: 'Close collections',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (showDateNav) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  key: const Key('debt_collections_prev'),
                  tooltip: 'Previous day',
                  onPressed: loading ? null : onPreviousDay,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    key: const Key('debt_collections_date'),
                    formatCollectionDateLabel(date),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('debt_collections_next'),
                  tooltip: 'Next day',
                  onPressed: loading || nextDisabled ? null : onNextDay,
                  icon: const Icon(Icons.chevron_right),
                ),
                if (date != today && onJumpToday != null)
                  TextButton(
                    key: const Key('debt_collections_today'),
                    onPressed: loading ? null : onJumpToday,
                    child: const Text('Today'),
                  ),
              ],
            ),
          ],
          Text(
            '$count payment${count == 1 ? '' : 's'} · ${_kes(total)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (loading && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No collections on this day. Debt payments recorded here will list the customer, amount paid, and remaining balance.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DebtCollectionTile(
                  row: row,
                  onOpenCustomer: onOpenCustomer == null
                      ? null
                      : () => onOpenCustomer!(row),
                ),
              ),
        ],
      ),
    );
  }
}

class DebtCollectionTile extends StatelessWidget {
  const DebtCollectionTile({
    super.key,
    required this.row,
    this.onOpenCustomer,
  });

  final DebtCollectionRow row;
  final VoidCallback? onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final remainingText = row.stillOwes
        ? '${row.remainingLabel} ${_kes(row.remainingDebt)}'
        : 'Settled';
    final notes = [
      if (row.reference.isNotEmpty) row.reference,
      if (row.notes.isNotEmpty) row.notes,
    ].join(' · ');

    return Container(
      key: Key('collection_row_${row.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                formatCollectionTime(row.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Text(
                remainingText,
                key: Key('collection_remaining_${row.id}'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: row.stillOwes
                      ? AppColors.destructive
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            key: Key('collection_customer_${row.id}'),
            onTap: onOpenCustomer,
            child: Text(
              row.customerName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: onOpenCustomer == null ? null : AppColors.primary,
                decoration: onOpenCustomer == null
                    ? null
                    : TextDecoration.underline,
              ),
            ),
          ),
          if (row.subtitle.isNotEmpty)
            Text(
              row.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Amount paid',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Text(
                key: Key('collection_amount_${row.id}'),
                _kes(row.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (row.receivedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Received by ${row.receivedBy}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
