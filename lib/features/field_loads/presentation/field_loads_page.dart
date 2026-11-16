import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../customers/application/customers_controllers.dart';
import '../../customers/domain/customer.dart';
import '../application/field_loads_controller.dart';
import '../domain/field_load.dart';

/// Field load on the phone: what the agent is carrying, what they sold, and
/// what they brought back. Shop stock is not taken again when they sell.
class FieldLoadsPage extends ConsumerStatefulWidget {
  const FieldLoadsPage({super.key});

  @override
  ConsumerState<FieldLoadsPage> createState() => _FieldLoadsPageState();
}

class _FieldLoadsPageState extends ConsumerState<FieldLoadsPage> {
  final _qty = TextEditingController(text: '1');
  final _paid = TextEditingController();
  final _returns = <int, TextEditingController>{};
  int? _lineId;
  CustomerSummary? _customer;
  String _payment = 'cash';
  bool _busy = false;

  @override
  void dispose() {
    _qty.dispose();
    _paid.dispose();
    for (final controller in _returns.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int lineId) {
    return _returns.putIfAbsent(lineId, TextEditingController.new);
  }

  Future<void> _run(Future<String?> Function() work, String success) async {
    setState(() => _busy = true);
    final error = await work();
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fieldLoadsProvider);
    final load = state.selected;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(fieldLoadsProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Text('Field load', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'A field load sale uses stock you are already carrying. It is not a field order.',
              style: theme.textTheme.bodyMedium,
            ),
            if (state.loading && state.book == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (load == null && !state.loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('No load is out. The shop issues stock before you leave.'),
              ),
            if ((state.book?.loads.length ?? 0) > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: load?.id,
                  items: [
                    for (final item in state.book!.loads)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.agentName} · ${_statusLabel(item.status)}'),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) ref.read(fieldLoadsProvider.notifier).select(id);
                  },
                ),
              ),
            if (load != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Current field load',
                            style: TextStyle(color: AppColors.primaryForeground, fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(load.displayStatus.isEmpty ? load.status : load.displayStatus),
                            style: const TextStyle(color: AppColors.primaryForeground, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      load.reference.isEmpty ? load.agentName : load.reference,
                      style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primaryForeground),
                    ),
                    Text(load.agentName, style: const TextStyle(color: AppColors.primaryForeground)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text('${load.unitsTaken}', style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primaryForeground))),
                        Expanded(child: Text('${load.unitsSold}', style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primaryForeground))),
                      ],
                    ),
                    const Row(
                      children: [
                        Expanded(child: Text('Units taken', style: TextStyle(color: AppColors.primaryForeground))),
                        Expanded(child: Text('Units sold', style: TextStyle(color: AppColors.primaryForeground))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final line in load.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CbSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.productName, style: theme.textTheme.titleMedium),
                        Text('Taken ${line.taken}'),
                        Text('Sold ${line.sold}', textAlign: TextAlign.right),
                        Text(
                          'Available: ${line.available}',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: line.taken == 0 ? 0 : (line.available / line.taken).clamp(0, 1),
                          color: AppColors.success,
                          backgroundColor: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              if (load.isOpen) _saleForm(load),
              if (load.isOpen) _returnForm(load),
              if (load.isPending && (state.book?.canApprove ?? false))
                Row(
                  children: [
                    Expanded(
                      child: CbPrimaryButton(
                        label: 'Approve reconciliation',
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => ref.read(fieldLoadsProvider.notifier).accept(load.id),
                                  'Returns are back on the shelf.',
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => ref.read(fieldLoadsProvider.notifier).reject(load.id),
                                  'Sent back to be counted again.',
                                ),
                        child: const Text('Send back for correction'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _saleForm(FieldLoad load) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('New field load sale'),
        const Text('This uses stock already on the load. It is not a field order.'),
        DropdownButton<int>(
          isExpanded: true,
          value: load.lines.any((line) => line.id == _lineId)
              ? _lineId
              : (load.lines.isEmpty ? null : load.lines.first.id),
          items: [
            for (final line in load.lines)
              DropdownMenuItem(value: line.id, child: Text(line.productName)),
          ],
          onChanged: (id) => setState(() => _lineId = id),
        ),
        TextField(
          controller: _qty,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        TextField(
          controller: _paid,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount received'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final choice in const ['cash', 'mpesa', 'credit', 'split'])
              ChoiceChip(
                label: Text(choice == 'mpesa' ? 'M-Pesa' : choice == 'credit' ? 'Credit' : choice == 'split' ? 'Split' : 'Cash'),
                selected: _payment == choice,
                onSelected: (_) => setState(() => _payment = choice),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _pickCustomer,
          child: Text(_customer == null ? 'Choose customer' : _customer!.name),
        ),
        const SizedBox(height: 8),
        CbPrimaryButton(
          key: const Key('field_load_sell'),
          label: 'Record a field load sale',
          onPressed: _busy
              ? null
              : () {
                  final lineId = _lineId ?? load.lines.first.id;
                  final line = load.lines.firstWhere((item) => item.id == lineId);
                  final quantity = int.tryParse(_qty.text) ?? 0;
                  _run(
                    () => ref.read(fieldLoadsProvider.notifier).sell(
                          loadId: load.id,
                          productId: line.productId,
                          variantId: line.variantId,
                          quantity: quantity,
                          customerId: _customer?.id,
                          amountPaid: _payment == 'credit' ? '0' : (_paid.text.trim().isEmpty ? '0' : _paid.text.trim()),
                          paymentMethod: _payment,
                        ),
                    'Field load sale recorded.',
                  );
                },
        ),
      ],
    );
  }

  Widget _returnForm(FieldLoad load) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Physical stock count'),
        const Text('Missing = taken − sold − returned.'),
        for (final line in load.lines)
          TextField(
            key: Key('return_${line.id}'),
            controller: _controllerFor(line.id),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: '${line.productName} returned'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('field_load_return'),
          onPressed: _busy
              ? null
              : () => _run(
                    () => ref.read(fieldLoadsProvider.notifier).submitReturn(
                          loadId: load.id,
                          lines: load.lines,
                          returned: {
                            for (final line in load.lines)
                              line.id: int.tryParse(_controllerFor(line.id).text) ?? 0,
                          },
                        ),
                    'Return count sent to the manager.',
                  ),
          child: const Text('Submit physical count'),
        ),
      ],
    );
  }

  Future<void> _pickCustomer() async {
    final search = TextEditingController();
    final picked = await showDialog<CustomerSummary>(
      context: context,
      builder: (context) {
        var matches = <CustomerSummary>[];
        var looking = false;
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('Customer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: looking
                          ? null
                          : () async {
                              setDialog(() => looking = true);
                              final result = await ref.read(customersApiProvider).list(
                                    search: search.text,
                                    pageSize: 8,
                                  );
                              final rows = result.getOrNull()?.results ?? const <CustomerSummary>[];
                              setDialog(() {
                                looking = false;
                                matches = rows;
                              });
                            },
                      child: const Text('Find'),
                    ),
                  ),
                  for (final customer in matches)
                    ListTile(
                      title: Text(customer.name),
                      onTap: () => Navigator.of(context).pop(customer),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Walk-in'),
                ),
              ],
            );
          },
        );
      },
    );
    search.dispose();
    if (!mounted || picked == null) return;
    setState(() => _customer = picked);
  }
}

/// Staff label for a load status. Unknown values stay as the raw key.
String _statusLabel(String status) {
  switch (status) {
    case 'shortage':
      return 'Shortage';
    case 'open':
      return 'Selling in field';
    case 'pending_review':
      return 'Awaiting approval';
    case 'accepted':
      return 'Accepted';
    default:
      return status;
  }
}
