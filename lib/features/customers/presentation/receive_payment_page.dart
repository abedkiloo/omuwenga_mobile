import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../payments/presentation/stk_wait_page.dart';
import '../../pos/domain/payment.dart';
import '../application/customers_controllers.dart';

class ReceivePaymentPage extends ConsumerStatefulWidget {
  const ReceivePaymentPage({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<ReceivePaymentPage> createState() => _ReceivePaymentPageState();
}

class _ReceivePaymentPageState extends ConsumerState<ReceivePaymentPage> {
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  PosPaymentMethod _method = PosPaymentMethod.cash;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _reference = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _seedAmount(double debt) {
    if (_initialized) return;
    _initialized = true;
    if (debt > 0) {
      _amount.text = debt.toStringAsFixed(2);
    }
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }

    var reference = _reference.text;
    if (_method == PosPaymentMethod.mpesa) {
      final detail = ref.read(customerDetailProvider(widget.customerId)).detail;
      final phone = detail?.phone?.trim() ?? '';
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer phone required for M-Pesa')),
        );
        return;
      }
      final paid = await showStkWaitSheet(
        context,
        amount: amount,
        phone: phone,
        purpose: 'debt',
        customerId: widget.customerId,
        customerName: detail?.name ?? '',
      );
      if (paid == null || !mounted) return;
      reference = paid.mpesaReceipt ?? paid.invoiceNumber;
    } else if (_method.requiresReference && reference.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment reference is required.')),
      );
      return;
    }

    final ok = await ref
        .read(customerDetailProvider(widget.customerId).notifier)
        .receivePayment(
          amount: amount,
          paymentMethod: _method.apiValue,
          reference: reference,
        );
    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      final err = ref.read(customerDetailProvider(widget.customerId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not receive payment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerDetailProvider(widget.customerId));
    final detail = state.detail;
    if (detail != null) {
      _seedAmount(detail.debtAmount);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Collect payment')),
      body: detail == null
          ? (state.loading
                ? const LoadingState()
                : ErrorState(
                    message: state.error ?? 'Customer unavailable',
                    onRetry: () => ref
                        .read(
                          customerDetailProvider(widget.customerId).notifier,
                        )
                        .load(widget.customerId),
                  ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              children: [
                Text(
                  detail.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  key: const Key('settle_amount_hero'),
                  _amount.text.isEmpty
                      ? detail.debtAmount.toStringAsFixed(2)
                      : _amount.text,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Wallet debt',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('settle_amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text('Method', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in const [
                      PosPaymentMethod.cash,
                      PosPaymentMethod.mpesa,
                      PosPaymentMethod.card,
                      PosPaymentMethod.other,
                    ])
                      ChoiceChip(
                        key: Key('settle_method_${m.name}'),
                        label: Text(m.label),
                        selected: _method == m,
                        onSelected: (_) => setState(() => _method = m),
                      ),
                  ],
                ),
                if (_method.requiresReference) ...[
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('settle_reference'),
                    controller: _reference,
                    decoration: const InputDecoration(
                      labelText: 'Payment reference',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                CbPrimaryButton(
                  key: const Key('settle_confirm'),
                  label: state.settling ? 'Processing…' : 'Confirm payment',
                  onPressed: state.settling ? null : _confirm,
                ),
              ],
            ),
    );
  }
}
