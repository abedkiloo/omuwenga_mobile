import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';
import '../domain/wallet_debt.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

String _shortDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

int? _ageDays(String? raw) {
  final dt = DateTime.tryParse(raw ?? '');
  if (dt == null) return null;
  return DateTime.now().difference(dt).inDays;
}

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerDetailProvider(customerId));
    final auth = ref.watch(authControllerProvider);
    final settings = ref
        .watch(customersSettingsProvider)
        .maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );

    final detail = state.detail;
    final showSettle =
        detail != null &&
        canSettleCustomerDebt(
          auth: auth,
          settings: settings,
          debtAmount: detail.debtAmount,
        );
    final canEdit =
        (auth.session?.permissions.canUpdateCustomers ?? false) &&
        settings.enableCustomerEdit;
    final canVisit = auth.session?.permissions.canPlaceVisitOrders ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Customer Ledger'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(
              child: CbStatusPill(
                label: 'Online · Synced',
                variant: CbStatusPillVariant.online,
                showOnlineDot: true,
              ),
            ),
          ),
          if (canEdit && detail != null)
            IconButton(
              key: const Key('customer_edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.customerEdit(detail.id)),
            ),
        ],
      ),
      body: _body(context, ref, state),
      bottomNavigationBar: detail == null
          ? null
          : _LedgerBottomBar(
              showSettle: showSettle,
              canVisit: canVisit,
              debtAmount: detail.debtAmount,
              onVisit: () => context.go(AppRoutes.siteVisit),
              onSettle: () => context.push(AppRoutes.customerSettle(detail.id)),
            ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CustomerDetailState state) {
    if (state.loading && state.detail == null) {
      return const LoadingState(label: 'Loading customer…');
    }
    if (state.error != null && state.detail == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref
            .read(customerDetailProvider(customerId).notifier)
            .load(customerId),
      );
    }
    final detail = state.detail;
    if (detail == null) {
      return EmptyState(
        title: 'Customer not found',
        message: 'This customer may have been removed.',
        primaryLabel: 'Back',
        onPrimary: () => Navigator.of(context).maybePop(),
      );
    }

    final aging = DebtAgingBuckets.fromOrders(detail.recentOrders);
    final standingColor = switch (detail.standing) {
      CustomerStanding.debt => AppColors.destructive,
      CustomerStanding.credit => AppColors.success,
      CustomerStanding.good => AppColors.success,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      children: [
        _ProfileCard(detail: detail),
        const SizedBox(height: 12),
        Text(
          key: const Key('customer_standing_hero'),
          detail.standingHeadline,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: standingColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _StandingGaugeCard(detail: detail),
        if (aging.total > 0) ...[
          const SizedBox(height: 12),
          _AgingCard(aging: aging),
        ],
        const SizedBox(height: 12),
        _LedgerActivitySection(detail: detail),
      ],
    );
  }
}

class _LedgerBottomBar extends StatelessWidget {
  const _LedgerBottomBar({
    required this.showSettle,
    required this.canVisit,
    required this.debtAmount,
    required this.onVisit,
    required this.onSettle,
  });

  final bool showSettle;
  final bool canVisit;
  final double debtAmount;
  final VoidCallback onVisit;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    if (!showSettle && !canVisit) return const SizedBox.shrink();
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: const Color(0x1A0F172A),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              if (canVisit) ...[
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onVisit,
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    label: const Text('Visit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (showSettle)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const Key('customer_settle'),
                      onPressed: onSettle,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                      ),
                      child: Text(
                        'Receive Payment  ${_kes(debtAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.detail});

  final CustomerDetail detail;

  String get _initials {
    final parts = detail.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = detail.locationLine;
    return CbSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accentSoft,
            child: Text(
              _initials,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail.notes != null && detail.notes!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail.notes!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (detail.customerCode != null &&
                        detail.customerCode!.isNotEmpty)
                      Text(
                        'ID: ${detail.customerCode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    if (detail.phone != null && detail.phone!.isNotEmpty)
                      Text(
                        detail.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Copy phone',
                onPressed: () async {
                  final phone = detail.phone?.trim() ?? '';
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No phone on file')),
                    );
                    return;
                  }
                  await Clipboard.setData(ClipboardData(text: phone));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Copied $phone')));
                },
                icon: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandingGaugeCard extends StatelessWidget {
  const _StandingGaugeCard({required this.detail});

  final CustomerDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debt = detail.debtAmount;
    final credit = detail.creditAmount;
    final outstanding =
        detail.totalOutstanding ??
        detail.standingSummary?.totalOutstanding ??
        0;
    final incurred = detail.standingSummary?.totalDebtIncurred ?? 0;
    final collected = detail.standingSummary?.totalDebtCollected ?? 0;
    final gaugeMax = [
      debt,
      outstanding,
      incurred,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final utilized = (debt / gaugeMax).clamp(0.0, 1.0);

    return CbSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Account Standing',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (debt > 0)
                CbStatusPill(
                  label: '${(utilized * 100).toStringAsFixed(0)}% of peak debt',
                  variant: CbStatusPillVariant.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: debt <= 0 ? 0 : utilized,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              color: utilized > 0.75
                  ? AppColors.destructive
                  : AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_kes(debt)} Outstanding',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: debt > 0 ? AppColors.destructive : null,
                  ),
                ),
              ),
              if (credit > 0)
                Text(
                  'Credit ${_kes(credit)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Wallet debt',
                  value: _kes(debt),
                  tint: const Color(0xFFE8F0FE),
                  valueColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: credit > 0 ? 'Wallet credit' : 'Invoice outstanding',
                  value: _kes(credit > 0 ? credit : outstanding),
                  tint: const Color(0xFFFFF4E5),
                  valueColor: AppColors.warning,
                ),
              ),
            ],
          ),
          if (incurred > 0 || collected > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Lifetime debt ${_kes(incurred)} · Collected ${_kes(collected)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          if (debt > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Open balance ${_kes(debt)}. Receive payment to clear wallet debt.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.tint,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color tint;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgingCard extends StatelessWidget {
  const _AgingCard({required this.aging});

  final DebtAgingBuckets aging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CbSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Aging Analysis',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Base Currency: KES',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AgeBucket(
                  title: '0–14 Days',
                  amount: aging.current,
                  caption: 'Current',
                  tint: const Color(0xFFE8F0FE),
                  accent: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AgeBucket(
                  title: '15–30 Days',
                  amount: aging.pending,
                  caption: 'Pending',
                  tint: const Color(0xFFFFF4E5),
                  accent: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AgeBucket(
                  title: '30+ Days',
                  amount: aging.overdue,
                  caption: 'Overdue',
                  tint: const Color(0xFFFEE2E2),
                  accent: AppColors.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgeBucket extends StatelessWidget {
  const _AgeBucket({
    required this.title,
    required this.amount,
    required this.caption,
    required this.tint,
    required this.accent,
  });

  final String title;
  final double amount;
  final String caption;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount.toStringAsFixed(0),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerActivitySection extends StatelessWidget {
  const _LedgerActivitySection({required this.detail});

  final CustomerDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLedger = detail.ledger.isNotEmpty;
    final hasOrders = detail.recentOrders.isNotEmpty;

    return CbSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ledger Activity',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasLedger && !hasOrders)
            Text(
              'No ledger activity yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            )
          else if (hasLedger)
            for (final entry in detail.ledger.take(20)) ...[
              _LedgerRow(entry: entry),
              const SizedBox(height: 10),
            ]
          else
            for (final order in detail.recentOrders.take(12)) ...[
              _OrderDebtRow(order: order),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final CustomerLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settlement = entry.isSettlement;
    final title = entry.saleNumber != null && entry.saleNumber!.isNotEmpty
        ? entry.saleNumber!
        : settlement
        ? 'Payment #${entry.id}'
        : 'Txn #${entry.id}';
    final amount = settlement
        ? -(entry.paymentAmount ?? entry.amount)
        : (entry.debtAdded ?? entry.amount);
    final subtitle = entry.notes.isNotEmpty
        ? entry.notes
        : entry.reference.isNotEmpty
        ? entry.reference
        : settlement
        ? 'Debt repayment'
        : entry.sourceType.replaceAll('_', ' ');
    final days = _ageDays(entry.createdAt);
    final statusLabel = settlement
        ? 'Cleared'
        : days == null
        ? entry.sourceType
        : days > 30
        ? 'Overdue: $days Days'
        : days > 14
        ? 'Pending: $days Days'
        : 'Current: $days Days';
    final (statusBg, statusFg) = settlement
        ? (const Color(0xFFDCFCE7), AppColors.success)
        : days != null && days > 30
        ? (const Color(0xFFFEE2E2), AppColors.destructive)
        : days != null && days > 14
        ? (const Color(0xFFFEF3C7), AppColors.warning)
        : (AppColors.accentSoft, AppColors.primary);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_shortDate(entry.createdAt).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _shortDate(entry.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                settlement ? 'Settled' : 'Amount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Text(
                amount < 0 ? '-${_kes(-amount)}' : _kes(amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: settlement ? AppColors.success : AppColors.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderDebtRow extends StatelessWidget {
  const _OrderDebtRow({required this.order});

  final CustomerOrderLite order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _ageDays(order.createdAt);
    final unpaid = order.hasOpenDebt;
    final statusLabel = !unpaid
        ? 'Paid'
        : days == null
        ? order.paymentStatus
        : days > 30
        ? 'Overdue: $days Days'
        : days > 14
        ? 'Pending: $days Days'
        : 'Current: $days Days';
    final (statusBg, statusFg) = !unpaid
        ? (const Color(0xFFDCFCE7), AppColors.success)
        : days != null && days > 30
        ? (const Color(0xFFFEE2E2), AppColors.destructive)
        : days != null && days > 14
        ? (const Color(0xFFFEF3C7), AppColors.warning)
        : (AppColors.accentSoft, AppColors.primary);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.saleNumber,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_shortDate(order.createdAt).isNotEmpty)
            Text(
              _shortDate(order.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(order.notes!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ] else if (order.itemCount != null) ...[
            const SizedBox(height: 4),
            Text('${order.itemCount} items'),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                unpaid ? 'Unpaid Balance' : 'Total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Text(
                _kes(unpaid ? order.debtAmount : order.total),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: unpaid ? AppColors.destructive : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
