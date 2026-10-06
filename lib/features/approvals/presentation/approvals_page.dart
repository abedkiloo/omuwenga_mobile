import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../sales_history/domain/sale.dart';
import '../application/approvals_controller.dart';
import '../data/approvals_api.dart';

String _kes(num value) {
  final n = value.toDouble();
  if (n == n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toStringAsFixed(2);
}

class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key});

  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(approvalsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(approvalsProvider);
    final ctrl = ref.read(approvalsProvider.notifier);
    final theme = Theme.of(context);

    if (!ctrl.canOpen) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'You do not have permission to approve sales or debt collections.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: () => ctrl.load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text('Approvals', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Review cashier sales and debt collections waiting for you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(color: AppColors.destructive),
              ),
            ],
            if (state.loading && state.totalCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (ctrl.canApproveSales) ...[
                const SizedBox(height: 20),
                Text(
                  'Sales (${state.sales.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (state.sales.isEmpty)
                  Text(
                    'No sales waiting.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  )
                else
                  for (final sale in state.sales)
                    _SaleApprovalCard(
                      sale: sale,
                      busy: state.acting,
                      onApprove: () => _act(() => ctrl.approveSale(sale.id)),
                      onReject: (reason) =>
                          _act(() => ctrl.rejectSale(sale.id, reason)),
                    ),
              ],
              if (ctrl.canApproveCollections) ...[
                const SizedBox(height: 20),
                Text(
                  'Debt collections (${state.collections.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (state.collections.isEmpty)
                  Text(
                    'No collections waiting.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  )
                else
                  for (final row in state.collections)
                    _CollectionApprovalCard(
                      row: row,
                      busy: state.acting,
                      onApprove: () =>
                          _act(() => ctrl.approveCollection(row.id)),
                      onReject: (reason) =>
                          _act(() => ctrl.rejectCollection(row.id, reason)),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _act(Future<String?> Function() action) async {
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Done')));
    }
  }
}

class _SaleApprovalCard extends StatefulWidget {
  const _SaleApprovalCard({
    required this.sale,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final SaleSummary sale;
  final bool busy;
  final VoidCallback onApprove;
  final Future<void> Function(String reason) onReject;

  @override
  State<_SaleApprovalCard> createState() => _SaleApprovalCardState();
}

class _SaleApprovalCardState extends State<_SaleApprovalCard> {
  bool _rejectOpen = false;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final waitingOnCashier = sale.needsSalespersonAction;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('approval_sale_${sale.id}'),
        padding: const EdgeInsets.all(12),
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
                        sale.saleNumber,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${sale.cashierName ?? 'Cashier'}'
                        '${sale.customerName != null && sale.customerName!.isNotEmpty ? ' · ${sale.customerName}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'KES ${_kes(sale.total)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            if (waitingOnCashier) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Text(
                  sale.rejectionReason?.isNotEmpty == true
                      ? 'Waiting on salesperson. Your comment: ${sale.rejectionReason}'
                      : 'Waiting on the salesperson to fix this sale and send it again.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(
                    key: Key('approval_sale_approve_${sale.id}'),
                    onPressed: widget.busy ? null : widget.onApprove,
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    key: Key('approval_sale_reject_${sale.id}'),
                    onPressed: widget.busy
                        ? null
                        : () => setState(() => _rejectOpen = !_rejectOpen),
                    child: const Text('Return'),
                  ),
                ],
              ),
              if (_rejectOpen) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason for the salesperson',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                    ),
                    onPressed: widget.busy
                        ? null
                        : () => widget.onReject(_reason.text),
                    child: const Text('Confirm return'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionApprovalCard extends StatefulWidget {
  const _CollectionApprovalCard({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final PendingDebtCollection row;
  final bool busy;
  final VoidCallback onApprove;
  final Future<void> Function(String reason) onReject;

  @override
  State<_CollectionApprovalCard> createState() =>
      _CollectionApprovalCardState();
}

class _CollectionApprovalCardState extends State<_CollectionApprovalCard> {
  bool _rejectOpen = false;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('approval_collection_${row.id}'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(row.customerName, style: Theme.of(context).textTheme.titleSmall),
            Text(
              'KES ${_kes(row.amount)} · ${(row.paymentMethod ?? 'cash').toUpperCase()}'
              '${row.madeByName != null ? ' · ${row.madeByName}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: widget.busy ? null : widget.onApprove,
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: widget.busy
                      ? null
                      : () => setState(() => _rejectOpen = !_rejectOpen),
                  child: const Text('Reject'),
                ),
              ],
            ),
            if (_rejectOpen) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  onPressed: widget.busy
                      ? null
                      : () => widget.onReject(_reason.text),
                  child: const Text('Confirm reject'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
