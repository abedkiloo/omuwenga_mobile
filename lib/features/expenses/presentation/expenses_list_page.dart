import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_bounded_sheet.dart';
import '../../../design_system/chrome/cb_filter_chip.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../approvals/application/approvals_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../application/expenses_controller.dart';
import '../domain/expense.dart';

String _kes(num value) {
  final n = value.toDouble();
  if (n == n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toStringAsFixed(2);
}

String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class ExpensesListPage extends ConsumerStatefulWidget {
  const ExpensesListPage({super.key});

  @override
  ConsumerState<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends ConsumerState<ExpensesListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expensesProvider.notifier).load();
    });
  }

  Future<void> _openForm({Expense? expense}) async {
    final saved = await showCbBoundedSheet<bool>(
      context: context,
      builder: (_) => _ExpenseFormSheet(expense: expense),
    );
    if (saved == true && mounted) {
      await ref.read(expensesProvider.notifier).load();
      await ref.read(approvalsProvider.notifier).load();
    }
  }

  Future<void> _openDetail(Expense expense) async {
    final result = await showCbBoundedSheet<Object>(
      context: context,
      builder: (_) => _ExpenseDetailSheet(expense: expense),
    );
    if (!mounted) return;
    if (result == 'edit') {
      await _openForm(expense: expense);
      return;
    }
    if (result == true) {
      await ref.read(expensesProvider.notifier).load();
      await ref.read(approvalsProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesProvider);
    final session = ref.watch(authControllerProvider).session;
    final canCreate = session?.permissions.canCreateExpenses ?? false;
    final canView = session?.permissions.canViewExpenses ?? false;

    if (!canView) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have permission to view expenses.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            key: const Key('expenses_refresh'),
            onPressed: () => ref.read(expensesProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const Key('expenses_add'),
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in [
                  const MapEntry('', 'All'),
                  const MapEntry('pending', 'Pending'),
                  const MapEntry('approved', 'Approved'),
                  const MapEntry('rejected', 'Rejected'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CbFilterChip(
                      label: entry.value,
                      selected: state.filters.status == entry.key,
                      onTap: () => ref.read(expensesProvider.notifier).load(
                            filters: state.filters.copyWith(status: entry.key),
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          Expanded(
            child: state.loading && state.items.isEmpty
                ? const LoadingState(label: 'Loading expenses…')
                : RefreshIndicator(
                    onRefresh: () => ref.read(expensesProvider.notifier).load(),
                    child: state.items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No expenses yet.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                            itemCount: state.items.length,
                            itemBuilder: (context, index) {
                              final expense = state.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: CbSurfaceCard(
                                  key: Key('expense_row_${expense.id}'),
                                  onTap: () => _openDetail(expense),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              expense.description,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                expense.statusLabel,
                                                if (expense.categoryName !=
                                                        null &&
                                                    expense.categoryName!
                                                        .isNotEmpty)
                                                  expense.categoryName!,
                                                if (expense.expenseDate
                                                    .isNotEmpty)
                                                  expense.expenseDate,
                                              ].join(' · '),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .mutedForeground,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'KES ${_kes(expense.amount)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDetailSheet extends ConsumerStatefulWidget {
  const _ExpenseDetailSheet({required this.expense});
  final Expense expense;

  @override
  ConsumerState<_ExpenseDetailSheet> createState() =>
      _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<_ExpenseDetailSheet> {
  bool _rejectOpen = false;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final state = ref.watch(expensesProvider);
    final session = ref.watch(authControllerProvider).session;
    final canApprove = sessionCanApproveExpenses(session);
    final canUpdate = session?.permissions.canUpdateExpenses ?? false;
    final canDelete = session?.permissions.canDeleteExpenses ?? false;
    final editable = expense.isEditable(
      makerCheckerEnabled: state.makerCheckerEnabled,
    );

    Future<void> act(Future<String?> Function() run) async {
      final err = await run();
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      Navigator.of(context).pop(true);
    }

    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.expenseNumber} · ${expense.statusLabel} · KES ${_kes(expense.amount)}',
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
              padding: const EdgeInsets.all(16),
              children: [
                _fact('Category', expense.categoryName ?? '—'),
                _fact('Date', expense.expenseDate.isEmpty ? '—' : expense.expenseDate),
                _fact('Payment', expense.paymentLabel),
                if (expense.vendor.isNotEmpty) _fact('Vendor', expense.vendor),
                if (expense.receiptNumber.isNotEmpty)
                  _fact('Receipt', expense.receiptNumber),
                if (expense.notes.isNotEmpty) _fact('Notes', expense.notes),
                if (expense.createdByName != null)
                  _fact('Requested by', expense.createdByName!),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expense.isPending && canApprove) ...[
                    if (_rejectOpen) ...[
                      TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'Why are you returning this?',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: state.saving
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
                              onPressed: state.saving
                                  ? null
                                  : () => act(
                                        () => ref
                                            .read(expensesProvider.notifier)
                                            .reject(expense.id, _reason.text),
                                      ),
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
                              key: Key('expense_approve_${expense.id}'),
                              onPressed: state.saving
                                  ? null
                                  : () => act(
                                        () => ref
                                            .read(expensesProvider.notifier)
                                            .approve(expense.id),
                                      ),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: state.saving
                                  ? null
                                  : () => setState(() => _rejectOpen = true),
                              child: const Text('Return'),
                            ),
                          ),
                        ],
                      ),
                  ],
                  if (expense.isRejected) ...[
                    FilledButton(
                      onPressed: state.saving
                          ? null
                          : () => act(
                                () => ref
                                    .read(expensesProvider.notifier)
                                    .resubmit(expense.id),
                              ),
                      child: const Text('Send back for approval'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (editable && canUpdate)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop('edit'),
                      child: const Text('Edit'),
                    ),
                  if (canDelete && !expense.isVoided) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                      ),
                      onPressed: state.saving
                          ? null
                          : () async {
                              final reason = expense.isPosted
                                  ? await _askVoidReason(context)
                                  : '';
                              if (expense.isPosted &&
                                  (reason == null || reason.trim().isEmpty)) {
                                return;
                              }
                              await act(
                                () => ref
                                    .read(expensesProvider.notifier)
                                    .deleteOrVoid(
                                      expense,
                                      reason: reason ?? '',
                                    ),
                              );
                            },
                      child: Text(expense.isPosted ? 'Void' : 'Delete'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askVoidReason(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void expense'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Void'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet({this.expense});
  final Expense? expense;

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _vendor;
  late final TextEditingController _receipt;
  late final TextEditingController _notes;
  late final TextEditingController _reason;
  late final TextEditingController _newCategory;
  int? _categoryId;
  String _paymentMethod = 'cash';
  String _expenseDate = _todayIso();
  bool _showNewCategory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amount = TextEditingController(
      text: e == null ? '' : (e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2)),
    );
    _description = TextEditingController(text: e?.description ?? '');
    _vendor = TextEditingController(text: e?.vendor ?? '');
    _receipt = TextEditingController(text: e?.receiptNumber ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _reason = TextEditingController();
    _newCategory = TextEditingController();
    _categoryId = e?.categoryId;
    _paymentMethod = e?.paymentMethod ?? 'cash';
    _expenseDate = (e?.expenseDate.isNotEmpty == true)
        ? e!.expenseDate
        : _todayIso();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _vendor.dispose();
    _receipt.dispose();
    _notes.dispose();
    _reason.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_expenseDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _expenseDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final draft = Expense(
      id: widget.expense?.id ?? 0,
      expenseNumber: widget.expense?.expenseNumber ?? '',
      amount: amount,
      description: _description.text,
      status: widget.expense?.status ?? 'pending',
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      vendor: _vendor.text,
      receiptNumber: _receipt.text,
      expenseDate: _expenseDate,
      notes: _notes.text,
    );
    final err = await ref.read(expensesProvider.notifier).save(
          draft: draft,
          existingId: widget.expense?.id,
          proposalReason: _reason.text,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesProvider);
    final categories = state.categories.where((c) => c.isActive).toList();

    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.expense == null ? 'Record expense' : 'Edit expense',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.destructive),
                    ),
                  ),
                TextField(
                  key: const Key('expense_description'),
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('expense_amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (KES)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: const Key('expense_category'),
                      isExpanded: true,
                      value: categories.any((c) => c.id == _categoryId)
                          ? _categoryId
                          : null,
                      hint: const Text('Choose category'),
                      items: [
                        for (final cat in categories)
                          DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                      ],
                      onChanged: (id) => setState(() => _categoryId = id),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showNewCategory = !_showNewCategory),
                    child: Text(
                      _showNewCategory ? 'Hide new category' : 'Add category',
                    ),
                  ),
                ),
                if (_showNewCategory) ...[
                  TextField(
                    controller: _newCategory,
                    decoration: const InputDecoration(
                      labelText: 'New category name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: state.saving
                          ? null
                          : () async {
                              final err = await ref
                                  .read(expensesProvider.notifier)
                                  .createCategory(_newCategory.text);
                              if (!mounted) return;
                              if (err != null) {
                                setState(() => _error = err);
                                return;
                              }
                              final needle =
                                  _newCategory.text.trim().toLowerCase();
                              ExpenseCategory? created;
                              for (final c
                                  in ref.read(expensesProvider).categories) {
                                if (c.name.toLowerCase() == needle) {
                                  created = c;
                                  break;
                                }
                              }
                              setState(() {
                                _showNewCategory = false;
                                _categoryId = created?.id ?? _categoryId;
                                _newCategory.clear();
                              });
                            },
                      child: const Text('Save category'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _paymentMethod,
                      items: [
                        for (final entry in kExpensePaymentMethods.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _paymentMethod = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expense date'),
                  subtitle: Text(_expenseDate),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                TextField(
                  controller: _vendor,
                  decoration: const InputDecoration(
                    labelText: 'Vendor (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _receipt,
                  decoration: const InputDecoration(
                    labelText: 'Receipt number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                if (state.makerCheckerEnabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('expense_proposal_reason'),
                    controller: _reason,
                    decoration: const InputDecoration(
                      labelText: 'Reason for this entry',
                      border: OutlineInputBorder(),
                      helperText:
                          'Submitted for approval — accounts update after an admin approves.',
                    ),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: const Key('expense_save'),
                onPressed: state.saving ? null : _submit,
                child: Text(
                  state.makerCheckerEnabled
                      ? 'Submit for approval'
                      : (widget.expense == null ? 'Save expense' : 'Save changes'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
