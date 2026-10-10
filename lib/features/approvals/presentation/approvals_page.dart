import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_bounded_sheet.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../expenses/domain/expense.dart';
import '../../sales_history/domain/sale.dart';
import '../application/approvals_controller.dart';
import '../data/approvals_api.dart';
import '../domain/approval_details.dart';
import 'approval_details_panel.dart';
import '../../../core/format/money.dart';

ApprovalDetails expenseApprovalDetails(Expense expense) {
  return ApprovalDetails(
    sections: [
      ApprovalSection(
        title: 'Expense',
        facts: [
          ApprovalFact(label: 'Reference', value: expense.expenseNumber),
          ApprovalFact(
            label: 'Amount',
            value: expense.amount.toString(),
            kind: 'money',
          ),
          if (expense.categoryName != null && expense.categoryName!.isNotEmpty)
            ApprovalFact(label: 'Category', value: expense.categoryName!),
          if (expense.expenseDate.isNotEmpty)
            ApprovalFact(label: 'Expense date', value: expense.expenseDate),
          ApprovalFact(label: 'Payment method', value: expense.paymentLabel),
          if (expense.vendor.isNotEmpty)
            ApprovalFact(label: 'Vendor', value: expense.vendor),
          if (expense.receiptNumber.isNotEmpty)
            ApprovalFact(label: 'Receipt number', value: expense.receiptNumber),
          if (expense.description.isNotEmpty)
            ApprovalFact(label: 'Description', value: expense.description),
          if (expense.notes.isNotEmpty)
            ApprovalFact(label: 'Notes', value: expense.notes),
          if (expense.createdByName != null &&
              expense.createdByName!.isNotEmpty)
            ApprovalFact(label: 'Requested by', value: expense.createdByName!),
        ],
      ),
    ],
  );
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
              'You do not have permission to approve sales, debt collections, or expenses.',
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
              'Tap a request to review every detail, then approve or return it.',
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
                      onOpen: () => _openSaleReview(sale),
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
                      onOpen: () => _openCollectionReview(row),
                    ),
              ],
              if (ctrl.canApproveExpenses) ...[
                const SizedBox(height: 20),
                Text(
                  'Expenses (${state.expenses.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (state.expenses.isEmpty)
                  Text(
                    'No expenses waiting.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  )
                else
                  for (final expense in state.expenses)
                    _ExpenseApprovalCard(
                      expense: expense,
                      busy: state.acting,
                      onOpen: () => _openExpenseReview(expense),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openExpenseReview(Expense expense) async {
    final ctrl = ref.read(approvalsProvider.notifier);
    await showCbBoundedSheet<void>(
      context: context,
      heightFactor: 0.9,
      builder: (ctx) => _ApprovalReviewSheet(
        title: expense.description.isNotEmpty
            ? expense.description
            : expense.expenseNumber,
        subtitle:
            '${formatKes(expense.amount, dropTrailingZeros: true)} · ${expense.paymentLabel}'
            '${expense.createdByName != null ? ' · ${expense.createdByName}' : ''}',
        details: expenseApprovalDetails(expense),
        busy: ref.read(approvalsProvider).acting,
        onApprove: () async {
          final err = await ctrl.approveExpense(expense.id);
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          _toast(err);
        },
        onReject: (reason) async {
          final err = await ctrl.rejectExpense(expense.id, reason);
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          _toast(err);
        },
      ),
    );
  }

  Future<void> _openSaleReview(SaleSummary sale) async {
    final ctrl = ref.read(approvalsProvider.notifier);
    var details = sale.approvalDetails;
    if (details.isEmpty) {
      final api = ref.read(approvalsApiProvider);
      final result = await api.saleDetail(sale.id);
      if (!mounted) return;
      result.when(
        success: (detail) {
          details = detail.approvalDetails;
          if (details.isEmpty && detail.items.isNotEmpty) {
            details = ApprovalDetails(
              sections: [
                ApprovalSection(
                  title: 'Sale',
                  facts: [
                    ApprovalFact(label: 'Sale number', value: detail.saleNumber),
                    if (detail.customerName != null &&
                        detail.customerName!.isNotEmpty)
                      ApprovalFact(
                        label: 'Customer',
                        value: detail.customerName!,
                      ),
                    if (detail.cashierName != null &&
                        detail.cashierName!.isNotEmpty)
                      ApprovalFact(
                        label: 'Sold by',
                        value: detail.cashierName!,
                      ),
                    if (detail.notes != null && detail.notes!.isNotEmpty)
                      ApprovalFact(label: 'Notes', value: detail.notes!),
                  ],
                ),
                ApprovalSection(
                  title: 'Items',
                  lines: [
                    for (final line in detail.items)
                      ApprovalLine(
                        name: line.productName,
                        variant: line.variantName ?? '',
                        quantity: line.quantity == line.quantity.roundToDouble()
                            ? line.quantity.toStringAsFixed(0)
                            : line.quantity.toString(),
                        unitPrice: line.unitPrice.toString(),
                        subtotal: line.lineTotal.toString(),
                      ),
                  ],
                ),
                ApprovalSection(
                  title: 'Money',
                  facts: [
                    ApprovalFact(
                      label: 'Total',
                      value: detail.total.toString(),
                      kind: 'money',
                    ),
                    ApprovalFact(
                      label: 'Amount paid',
                      value: detail.amountPaid.toString(),
                      kind: 'money',
                    ),
                    if (detail.paymentMethod != null)
                      ApprovalFact(
                        label: 'Payment method',
                        value: detail.paymentMethod!,
                      ),
                    if (detail.debtAmount > 0)
                      ApprovalFact(
                        label: 'Balance left as debt',
                        value: detail.debtAmount.toString(),
                        kind: 'money',
                      ),
                  ],
                ),
              ],
            );
          }
        },
        failure: (_, _) {},
      );
    }
    if (!mounted) return;
    await showCbBoundedSheet<void>(
      context: context,
      heightFactor: 0.9,
      builder: (ctx) => _ApprovalReviewSheet(
        title: sale.saleNumber,
        subtitle:
            '${sale.cashierName ?? 'Cashier'}'
            '${sale.customerName != null && sale.customerName!.isNotEmpty ? ' · ${sale.customerName}' : ''}'
            ' · ${formatKes(sale.total, dropTrailingZeros: true)}',
        details: details,
        waitingOnCashier: sale.needsSalespersonAction,
        waitingMessage: sale.rejectionReason?.isNotEmpty == true
            ? 'Waiting on salesperson. Your comment: ${sale.rejectionReason}'
            : 'Waiting on the salesperson to fix this sale and send it again.',
        busy: ref.read(approvalsProvider).acting,
        onApprove: sale.needsSalespersonAction
            ? null
            : () async {
                final err = await ctrl.approveSale(sale.id);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                _toast(err);
              },
        onReject: sale.needsSalespersonAction
            ? null
            : (reason) async {
                final err = await ctrl.rejectSale(sale.id, reason);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                _toast(err);
              },
      ),
    );
  }

  Future<void> _openCollectionReview(PendingDebtCollection row) async {
    final ctrl = ref.read(approvalsProvider.notifier);
    await showCbBoundedSheet<void>(
      context: context,
      heightFactor: 0.9,
      builder: (ctx) => _ApprovalReviewSheet(
        title: row.customerName,
        subtitle:
            '${formatKes(row.amount, dropTrailingZeros: true)} · ${(row.paymentMethod ?? 'cash').toUpperCase()}'
            '${row.madeByName != null ? ' · ${row.madeByName}' : ''}',
        details: row.details,
        reason: row.reason,
        busy: ref.read(approvalsProvider).acting,
        onApprove: () async {
          final err = await ctrl.approveCollection(row.id);
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          _toast(err);
        },
        onReject: (reason) async {
          final err = await ctrl.rejectCollection(row.id, reason);
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          _toast(err);
        },
      ),
    );
  }

  void _toast(String? err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Done')),
    );
  }
}

class _ApprovalReviewSheet extends StatefulWidget {
  const _ApprovalReviewSheet({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.busy,
    this.reason,
    this.waitingOnCashier = false,
    this.waitingMessage,
    this.onApprove,
    this.onReject,
  });

  final String title;
  final String subtitle;
  final ApprovalDetails details;
  final bool busy;
  final String? reason;
  final bool waitingOnCashier;
  final String? waitingMessage;
  final Future<void> Function()? onApprove;
  final Future<void> Function(String reason)? onReject;

  @override
  State<_ApprovalReviewSheet> createState() => _ApprovalReviewSheetState();
}

class _ApprovalReviewSheetState extends State<_ApprovalReviewSheet> {
  bool _rejectOpen = false;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (widget.reason != null && widget.reason!.trim().isNotEmpty) ...[
                  Text(
                    'WHY THEY ASKED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.reason!),
                  ),
                  const SizedBox(height: 16),
                ],
                ApprovalDetailsPanel(
                  key: const Key('approval_details_panel'),
                  details: widget.details,
                ),
                if (widget.waitingOnCashier) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Text(
                      widget.waitingMessage ??
                          'Waiting on the salesperson to fix this sale.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.waitingOnCashier &&
              (widget.onApprove != null || widget.onReject != null))
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_rejectOpen) ...[
                      TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'Reason for the requester',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.busy
                                  ? null
                                  : () => setState(() => _rejectOpen = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.destructive,
                              ),
                              onPressed: widget.busy
                                  ? null
                                  : () => widget.onReject?.call(_reason.text),
                              child: const Text('Confirm return'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              key: const Key('approval_sheet_approve'),
                              onPressed: widget.busy
                                  ? null
                                  : () => widget.onApprove?.call(),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('approval_sheet_reject'),
                              onPressed: widget.busy
                                  ? null
                                  : () => setState(() => _rejectOpen = true),
                              child: const Text('Return'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SaleApprovalCard extends StatelessWidget {
  const _SaleApprovalCard({
    required this.sale,
    required this.busy,
    required this.onOpen,
  });

  final SaleSummary sale;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final waitingOnCashier = sale.needsSalespersonAction;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('approval_sale_${sale.id}'),
        onTap: busy ? null : onOpen,
        child: Row(
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
                  if (waitingOnCashier)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Waiting on salesperson',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFFC2410C)),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tap for full details',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatKes(sale.total),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _ExpenseApprovalCard extends StatelessWidget {
  const _ExpenseApprovalCard({
    required this.expense,
    required this.busy,
    required this.onOpen,
  });

  final Expense expense;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('approval_expense_${expense.id}'),
        onTap: busy ? null : onOpen,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description.isNotEmpty
                        ? expense.description
                        : expense.expenseNumber,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    [
                      if (expense.categoryName != null &&
                          expense.categoryName!.isNotEmpty)
                        expense.categoryName!,
                      expense.paymentLabel,
                      if (expense.createdByName != null)
                        expense.createdByName!,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap for full details',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatKes(expense.amount),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _CollectionApprovalCard extends StatelessWidget {
  const _CollectionApprovalCard({
    required this.row,
    required this.busy,
    required this.onOpen,
  });

  final PendingDebtCollection row;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('approval_collection_${row.id}'),
        onTap: busy ? null : onOpen,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.customerName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${(row.paymentMethod ?? 'cash').toUpperCase()}'
                    '${row.madeByName != null ? ' · ${row.madeByName}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap for full details',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedForeground),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatKes(row.amount),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
