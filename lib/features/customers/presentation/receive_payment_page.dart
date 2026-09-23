import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../pos/domain/payment.dart';
import '../application/customers_controllers.dart';
import '../domain/mpesa_receipt.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

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
  bool _attempted = false;

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

  String? get _amountError {
    if (!_attempted && _amount.text.trim().isEmpty) return null;
    return paymentAmountValidationMessage(_amount.text);
  }

  String? get _referenceError {
    if (_method == PosPaymentMethod.mpesa) {
      if (!_attempted && _reference.text.trim().isEmpty) return null;
      return mpesaReceiptValidationMessage(_reference.text);
    }
    if (_method.requiresReference && _attempted && _reference.text.trim().isEmpty) {
      return 'Enter the card or receipt reference.';
    }
    return null;
  }

  Future<void> _confirm() async {
    setState(() => _attempted = true);
    final amountError = paymentAmountValidationMessage(_amount.text);
    if (amountError != null) return;
    final amount = parsePaymentAmount(_amount.text)!;

    var reference = _reference.text;
    if (_method == PosPaymentMethod.mpesa) {
      if (mpesaReceiptValidationMessage(reference) != null) return;
      reference = normalizeMpesaReceipt(reference);
    } else if (_method.requiresReference && reference.trim().isEmpty) {
      return;
    }

    final detail = ref.read(customerDetailProvider(widget.customerId)).detail;
    if (detail == null) return;

    final confirmed = await showCommitConfirm(
      context: context,
      title: 'Proceed with this payment?',
      description:
          'Do you really want to continue with this transaction? '
          'This records the payment on the customer account.',
      rows: [
        CommitSummaryRow(label: 'Customer', value: detail.name),
        CommitSummaryRow(label: 'Amount', value: _kes(amount), emphasis: true),
        CommitSummaryRow(label: 'Method', value: _method.label),
        if (reference.trim().isNotEmpty)
          CommitSummaryRow(
            label: _method == PosPaymentMethod.mpesa
                ? 'M-Pesa code'
                : 'Reference',
            value: reference.trim(),
          ),
        if (detail.debtAmount > 0)
          CommitSummaryRow(
            label: 'Current debt',
            value: _kes(detail.debtAmount),
          ),
      ],
      confirmLabel: 'Yes, record payment',
      cancelLabel: 'Back',
      confirmKey: const Key('settle_commit_confirm'),
      cancelKey: const Key('settle_commit_cancel'),
    );
    if (!confirmed || !mounted) return;

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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount (KES) *',
                    hintText: kPaymentAmountExample,
                    helperText: kPaymentAmountHelper,
                    helperMaxLines: 3,
                    errorText: _amountError,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
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
                if (_method == PosPaymentMethod.mpesa ||
                    _method.requiresReference) ...[
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('settle_reference'),
                    controller: _reference,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _method == PosPaymentMethod.mpesa
                        ? [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9 ]'),
                            ),
                          ]
                        : const [],
                    decoration: InputDecoration(
                      labelText: _method == PosPaymentMethod.mpesa
                          ? 'M-Pesa code *'
                          : 'Payment reference',
                      hintText: _method == PosPaymentMethod.mpesa
                          ? kMpesaReceiptExample
                          : 'Receipt or last 4 digits',
                      helperText: _method == PosPaymentMethod.mpesa
                          ? kMpesaReceiptHelper
                          : 'Optional for cash; required for card.',
                      helperMaxLines: 3,
                      errorText: _referenceError,
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                CbPrimaryButton(
                  key: const Key('settle_confirm'),
                  label: state.settling ? 'Processing…' : 'Record payment',
                  onPressed: state.settling ? null : _confirm,
                ),
              ],
            ),
    );
  }
}
