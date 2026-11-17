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

/// Field load on the phone.
///
/// The open load is one screen of stock the agent is carrying. Recording a
/// sale and counting the return are separate steps, so a small screen does
/// not hide the action under a long list. A sale uses stock already on the
/// load and does not take it off the shop shelf again.
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
  String _panel = 'stock';
  bool _paidEdited = false;
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
    setState(() {
      _busy = false;
      if (error == null) _panel = 'stock';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? success)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fieldLoadsProvider);
    final load = state.selected;
    final selling = load != null && load.isOpen && _panel == 'sale';
    final returning = load != null && load.isOpen && _panel == 'return';

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(fieldLoadsProvider.notifier).load(),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  if (selling)
                    _saleStep(load)
                  else if (returning)
                    _returnStep(load)
                  else
                    ..._stockStep(state, load),
                ],
              ),
            ),
          ),
          if (load != null && load.isOpen && !selling && !returning)
            _stockActions(load),
        ],
      ),
    );
  }

  List<Widget> _stockStep(FieldLoadsState state, FieldLoad? load) {
    final theme = Theme.of(context);
    return [
      Text('Field load', style: theme.textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        'Sell what you are carrying, then bring the rest back.',
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
                  child: Text(
                    '${item.reference.isEmpty ? item.agentName : item.reference} · ${_statusLabel(item.status)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() => _panel = 'stock');
              ref.read(fieldLoadsProvider.notifier).select(id);
            },
          ),
        ),
      if (load != null) ...[
        const SizedBox(height: 12),
        _loadBanner(load),
        const SizedBox(height: 16),
        Text('My available stock', style: theme.textTheme.titleMedium),
        for (final line in load.lines) ...[
          const SizedBox(height: 8),
          _stockCard(load, line),
        ],
        if (load.isAwaitingIssue && (state.book?.canApprove ?? false)) ...[
          const SizedBox(height: 16),
          const Text('Shop stock stays put until you approve these quantities.'),
          const SizedBox(height: 8),
          CbPrimaryButton(
            label: 'Approve quantities',
            onPressed: _busy
                ? null
                : () => _run(
                      () => ref.read(fieldLoadsProvider.notifier).approveIssue(load.id),
                      'Load approved. Those quantities have left the shop.',
                    ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref.read(fieldLoadsProvider.notifier).declineIssue(load.id),
                        'Sent back to the sales person.',
                      ),
              child: const Text('Send the quantities back'),
            ),
          ),
        ],
        if (load.isPending && (state.book?.canApprove ?? false)) ...[
          const SizedBox(height: 16),
          CbPrimaryButton(
            label: 'Approve reconciliation',
            onPressed: _busy
                ? null
                : () => _run(
                      () => ref.read(fieldLoadsProvider.notifier).accept(load.id),
                      'Returns are back on the shelf.',
                    ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
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
      ],
    ];
  }

  Widget _loadBanner(FieldLoad load) {
    final theme = Theme.of(context);
    final issued = _issuedLabel(load.issuedAt);
    final who = [
      load.agentName,
      if (issued.isNotEmpty) 'Issued $issued',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'MY CURRENT FIELD LOAD',
                  maxLines: 2,
                  style: TextStyle(
                    color: AppColors.primaryForeground,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: load.isOpen ? AppColors.success : AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(load.displayStatus.isEmpty ? load.status : load.displayStatus),
                  style: TextStyle(
                    color: load.isOpen ? AppColors.primaryForeground : AppColors.foreground,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            load.reference.isEmpty ? 'Open load' : load.reference,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.primaryForeground,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            who,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.primaryForeground),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _bannerStat('${load.unitsTaken}', 'Units taken')),
              const SizedBox(width: 8),
              Expanded(child: _bannerStat('${load.unitsSold}', 'Units sold')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primaryForeground,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(label, style: const TextStyle(color: AppColors.primaryForeground, fontSize: 13)),
      ],
    );
  }

  /// One product in the bag.
  ///
  /// [load] is the open or closed load. [line] is one product on it.
  /// [selectable] is false on the sale step so the other products stay
  /// off this screen and this card does not open a second sale.
  ///
  /// Returns the card. A selectable card with stock opens the sale step.
  Widget _stockCard(FieldLoad load, FieldLoadLine line, {bool selectable = true}) {
    final canSell = selectable && load.isOpen && line.available > 0;
    return CbSurfaceCard(
      onTap: canSell ? () => _openSale(load, line.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text('Taken: ${line.taken}')),
              Text('Sold: ${line.sold}'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available: ${line.available}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_unitPrice(line.unitPrice)}/unit'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 6,
            value: line.taken == 0 ? 0 : (line.available / line.taken).clamp(0, 1),
            color: AppColors.success,
            backgroundColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _stockActions(FieldLoad load) {
    final canSell = load.lines.any((line) => line.available > 0);
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CbPrimaryButton(
                key: const Key('field_load_sell'),
                label: 'Record a field sale',
                onPressed: _busy || !canSell
                    ? null
                    : () => _openSale(
                          load,
                          load.lines.firstWhere((line) => line.available > 0).id,
                        ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  key: const Key('field_load_return'),
                  onPressed: _busy ? null : () => _openReturn(load),
                  child: const Text('Return to shop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saleStep(FieldLoad load) {
    final line = _selectedLine(load);
    final total = line == null ? 0.0 : _lineTotal(line);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Record a field sale'),
        if (line != null) ...[
          _stockCard(load, line, selectable: false),
          const SizedBox(height: 12),
          const Text('Quantity'),
          const SizedBox(height: 4),
          Row(
            children: [
              _stepperButton(Icons.remove, () => _setQuantity(line, (_quantity) - 1)),
              Expanded(
                child: TextField(
                  controller: _qty,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _setQuantity(line, _quantity, fromField: true),
                ),
              ),
              _stepperButton(Icons.add, () => _setQuantity(line, _quantity + 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Total', style: Theme.of(context).textTheme.bodySmall),
          Text(
            formatKes(total, dropTrailingZeros: true),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Payment'),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final choice in const ['cash', 'mpesa', 'credit']) ...[
                if (choice != 'cash') const SizedBox(width: 6),
                Expanded(child: _paymentButton(line, choice)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paid,
            enabled: _payment != 'credit',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount received',
              helperText: _payment == 'credit'
                  ? 'Nothing is received. The sale stays on the customer.'
                  : 'Cash or M-Pesa is the full total.',
            ),
            onChanged: (_) => _paidEdited = true,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _busy ? null : _pickCustomer,
              child: Text(
                _customer == null ? 'Choose customer' : _customer!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          CbPrimaryButton(
            key: const Key('field_load_save'),
            label: 'Save sale',
            onPressed: _busy
                ? null
                : () {
                    final quantity = _quantity;
                    _run(
                      () => ref.read(fieldLoadsProvider.notifier).sell(
                            loadId: load.id,
                            productId: line.productId,
                            variantId: line.variantId,
                            quantity: quantity,
                            customerId: _customer?.id,
                            amountPaid: _payment == 'credit'
                                ? '0'
                                : (_paid.text.trim().isEmpty ? '0' : _paid.text.trim()),
                            paymentMethod: _payment,
                          ),
                      'Field load sale recorded.',
                    );
                  },
          ),
        ],
      ],
    );
  }

  Widget _returnStep(FieldLoad load) {
    final blocked = load.lines.any((line) => _missingCount(line) < 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Return to shop'),
        const Text('Count what you brought back. Anything not sold and not returned stays missing.'),
        for (final line in load.lines) ...[
          const SizedBox(height: 12),
          Text(
            line.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Taken ${line.taken} · Sold ${line.sold} · Still out ${line.available}'),
          TextField(
            key: Key('return_${line.id}'),
            controller: _controllerFor(line.id),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Returned',
              helperText: _missingCount(line) < 0
                  ? 'That is more than the units still out.'
                  : 'Missing ${_missingCount(line)}',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        CbPrimaryButton(
          key: const Key('field_load_submit_count'),
          label: 'Submit physical count',
          onPressed: _busy || blocked
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
        ),
      ],
    );
  }

  Widget _stepTitle(String title) {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() => _panel = 'stock'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to stock',
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }

  Widget _paymentButton(FieldLoadLine line, String choice) {
    final selected = _payment == choice;
    final label = choice == 'mpesa' ? 'M-Pesa' : choice == 'credit' ? 'Credit' : 'Cash';
    return SizedBox(
      height: 44,
      child: selected
          ? FilledButton(
              onPressed: () => _choosePayment(line, choice),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          : OutlinedButton(
              onPressed: () => _choosePayment(line, choice),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
    );
  }

  /// Opens the sale step for one product on [load].
  ///
  /// [lineId] must be a line on that load. Quantity starts at 1 and is
  /// capped at the units still available, which is 0–100000. The amount
  /// received starts as the full total unless the agent has already typed
  /// one. This does not move shop stock.
  ///
  /// Returns immediately after the step is shown.
  void _openSale(FieldLoad load, int lineId) {
    final line = load.lines.where((item) => item.id == lineId);
    final chosen = line.isEmpty ? null : line.first;
    setState(() {
      _lineId = lineId;
      _panel = 'sale';
      _qty.text = '1';
      _paidEdited = false;
      if (chosen != null && _payment != 'credit') {
        _paid.text = _moneyInput(_unitAmount(chosen.unitPrice));
      }
    });
  }

  /// Opens the return count for [load].
  ///
  /// Each empty return starts as the units still out, so a full return is
  /// already filled in. A return above the units still out is blocked.
  /// The manager still accepts the count before stock goes back on the shelf.
  ///
  /// Returns immediately. Does nothing when the load is not open.
  void _openReturn(FieldLoad load) {
    if (!load.isOpen) return;
    for (final line in load.lines) {
      final controller = _controllerFor(line.id);
      if (controller.text.trim().isEmpty) {
        controller.text = '${line.available}';
      }
    }
    setState(() => _panel = 'return');
  }

  /// Sets the sale quantity for [line] and keeps the received amount in step.
  ///
  /// [next] is clamped from 1 to the units still available. When [fromField]
  /// is true the typed text is kept even if it is still empty. A suggested
  /// amount is replaced only until the agent edits the amount. Does not
  /// record the sale.
  void _setQuantity(FieldLoadLine line, int next, {bool fromField = false}) {
    final cap = line.available < 1 ? 1 : line.available;
    final qty = next.clamp(1, cap);
    setState(() {
      if (!fromField || _qty.text.isNotEmpty) {
        _qty.text = '$qty';
      }
      if (!_paidEdited && _payment != 'credit') {
        _paid.text = _moneyInput(_unitAmount(line.unitPrice) * qty);
      }
    });
  }

  void _choosePayment(FieldLoadLine line, String choice) {
    setState(() {
      _payment = choice;
      if (choice == 'credit') {
        _paid.text = '0';
      } else if (!_paidEdited) {
        _paid.text = _moneyInput(_lineTotal(line));
      }
    });
  }

  FieldLoadLine? _selectedLine(FieldLoad load) {
    for (final line in load.lines) {
      if (line.id == _lineId && line.available > 0) return line;
    }
    for (final line in load.lines) {
      if (line.available > 0) return line;
    }
    return load.lines.isEmpty ? null : load.lines.first;
  }

  int get _quantity => int.tryParse(_qty.text) ?? 0;

  double _lineTotal(FieldLoadLine line) => _unitAmount(line.unitPrice) * _quantity;

  /// Units returned subtracted from the units still out.
  ///
  /// A blank field counts as 0. The result can be negative when the typed
  /// return is larger than what is still out. It does not change stock.
  int _missingCount(FieldLoadLine line) {
    final returned = int.tryParse(_controllerFor(line.id).text) ?? 0;
    return line.available - returned;
  }

  /// Opens the customer search used when recording a field-load sale.
  ///
  /// Search uses the same lookup as the shop: name, phone, or place.
  /// Walk-in closes the dialog with no customer. At most 20 matches.
  /// The list height is half the screen, capped at 320, so a small phone
  /// can still reach Walk-in.
  ///
  /// Returns when the dialog closes.
  ///
  /// A failed lookup leaves the list empty.
  Future<void> _pickCustomer() async {
    final search = TextEditingController();
    final height = MediaQuery.sizeOf(context).height;
    final listHeight = height * 0.5 > 320 ? 320.0 : height * 0.5;
    final picked = await showDialog<CustomerSummary>(
      context: context,
      builder: (context) {
        var matches = <CustomerSummary>[];
        var looking = false;
        return StatefulBuilder(
          builder: (context, setDialog) {
            Future<void> find() async {
              setDialog(() => looking = true);
              final result = await ref.read(customersApiProvider).list(
                    search: search.text,
                    pageSize: 20,
                  );
              final rows = result.getOrNull()?.results ?? const <CustomerSummary>[];
              setDialog(() {
                looking = false;
                matches = rows;
              });
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Customer'),
              content: SizedBox(
                width: double.maxFinite,
                height: listHeight,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('field_load_customer_search'),
                      controller: search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Name, phone, or place',
                      ),
                      onSubmitted: looking ? null : (_) => find(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: looking ? null : find,
                        child: const Text('Find'),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final customer in matches)
                            ListTile(
                              title: Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: customer.locationLine.isEmpty
                                  ? null
                                  : Text(
                                      customer.locationLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => Navigator.of(context).pop(customer),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
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

/// Short issued date, such as `16 Nov 2026`. Blank when [iso] is empty.
String _issuedLabel(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = parsed.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// Catalog price as `KES 150`, or `KES 0` when the price is missing.
String _unitPrice(String raw) => formatKes(_unitAmount(raw), dropTrailingZeros: true);

/// Decimal price, never below zero. A blank or bad value is 0.
double _unitAmount(String raw) {
  final value = double.tryParse(raw) ?? 0;
  return value < 0 ? 0 : value;
}

/// Whole-number money for an input, or 2 decimals when there are cents.
String _moneyInput(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

/// Staff label for a load status. Unknown values stay as the raw key.
String _statusLabel(String status) {
  switch (status) {
    case 'shortage':
      return 'Shortage';
    case 'open':
      return 'Open load';
    case 'awaiting_issue':
      return 'Waiting for manager';
    case 'issue_rejected':
      return 'Sent back';
    case 'pending_review':
      return 'Awaiting approval';
    case 'accepted':
      return 'Accepted';
    default:
      return status;
  }
}
