import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/domain/payment.dart';
import '../../payments/domain/mpesa_capture.dart';
import '../../payments/presentation/mpesa_capture.dart';
import '../../payments/presentation/stk_wait_page.dart';
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
  late final TextEditingController _phone;
  PosPaymentMethod _method = PosPaymentMethod.cash;
  MpesaCaptureMode _mpesaCapture = MpesaCaptureMode.prompt;
  bool _initialized = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _reference = TextEditingController();
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seedAmount(double debt, {String? phone}) {
    if (_initialized) return;
    _initialized = true;
    if (debt > 0) {
      _amount.text = debt.toStringAsFixed(2);
    }
    if (phone != null && phone.trim().isNotEmpty) {
      _phone.text = phone;
    }
  }

  String? get _amountError {
    if (!_attempted && _amount.text.trim().isEmpty) return null;
    return paymentAmountValidationMessage(_amount.text);
  }

  Future<void> _confirm() async {
    setState(() => _attempted = true);
    final amountError = paymentAmountValidationMessage(_amount.text);
    if (amountError != null) return;
    final amount = parsePaymentAmount(_amount.text)!;

    var reference = _reference.text;
    if (_method == PosPaymentMethod.mpesa) {
      if (_mpesaCapture == MpesaCaptureMode.prompt) {
        final phoneErr = phoneValidationMessage(_phone.text, required: true);
        if (phoneErr != null) return;
      } else {
        if (mpesaReceiptValidationMessage(reference) != null) return;
        reference = normalizeMpesaReceipt(reference);
      }
    }

    final detail = ref.read(customerDetailProvider(widget.customerId)).detail;
    if (detail == null) return;

    final canApprove =
        ref.read(authControllerProvider).session?.permissions.canApproveDebtManagement ??
        false;
    final confirmed = await showCommitConfirm(
      context: context,
      title: 'Proceed with this payment?',
      description: canApprove
          ? 'Do you really want to continue with this transaction? '
                'This records the payment on the customer account.'
          : 'Do you really want to continue with this transaction? '
                'A manager must approve it before the wallet is updated.',
      rows: [
        CommitSummaryRow(label: 'Customer', value: detail.name),
        CommitSummaryRow(label: 'Amount', value: _kes(amount), emphasis: true),
        CommitSummaryRow(label: 'Method', value: _method.label),
        if (_method == PosPaymentMethod.mpesa &&
            _mpesaCapture == MpesaCaptureMode.prompt)
          CommitSummaryRow(label: 'Phone', value: _phone.text.trim())
        else if (reference.trim().isNotEmpty)
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

    if (_method == PosPaymentMethod.mpesa &&
        _mpesaCapture == MpesaCaptureMode.prompt) {
      final paid = await showStkWaitSheet(
        context,
        amount: amount,
        phone: _phone.text.trim(),
        purpose: 'debt',
        customerId: widget.customerId,
        customerName: detail.name,
      );
      if (!mounted) return;
      if (paid == null) return;
      reference = paid.mpesaReceipt ?? paid.invoiceNumber;
      if (reference.trim().isEmpty) return;
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
      final queued = ref
          .read(customerDetailProvider(widget.customerId))
          .queuedForApproval;
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        if (router.canPop()) router.pop();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Submitted for manager approval — wallet unchanged until it is approved.'
                : 'Payment recorded.',
          ),
        ),
      );
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
      _seedAmount(detail.debtAmount, phone: detail.phone);
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
                    ])
                      ChoiceChip(
                        key: Key('settle_method_${m.name}'),
                        label: Text(m.label),
                        selected: _method == m,
                        onSelected: (_) => setState(() {
                          _method = m;
                          if (m != PosPaymentMethod.mpesa) {
                            _mpesaCapture = MpesaCaptureMode.prompt;
                          }
                        }),
                      ),
                  ],
                ),
                if (_method == PosPaymentMethod.mpesa) ...[
                  const SizedBox(height: 16),
                  MpesaCapture(
                    mode: _mpesaCapture,
                    onModeChanged: (next) => setState(() {
                      _mpesaCapture = next;
                      _attempted = false;
                    }),
                    phoneController: _phone,
                    codeController: _reference,
                    phoneFieldKey: const Key('settle_mpesa_phone'),
                    codeFieldKey: const Key('settle_reference'),
                    promptKey: const Key('settle_mpesa_capture_prompt'),
                    codeModeKey: const Key('settle_mpesa_capture_code'),
                    showErrors: _attempted,
                    onChanged: () => setState(() {}),
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
