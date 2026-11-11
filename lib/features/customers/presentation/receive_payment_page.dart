import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format/money.dart';
import '../../../core/media/image_upload_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../payments/domain/mpesa_capture.dart';
import '../../payments/presentation/mpesa_capture.dart';
import '../../payments/presentation/stk_wait_page.dart';
import '../../pos/domain/payment.dart';
import '../application/customers_controllers.dart';
import '../domain/mpesa_receipt.dart';

String _todayLocalDate() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

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
  late final TextEditingController _payerName;
  late final TextEditingController _payerPhone;
  late final TextEditingController _notes;
  PosPaymentMethod _method = PosPaymentMethod.cash;
  MpesaCaptureMode _mpesaCapture = MpesaCaptureMode.code;
  String _mpesaDestination = '';
  String _paymentDate = _todayLocalDate();
  Uint8List? _receiptBytes;
  String _receiptName = 'mpesa_receipt.jpg';
  String _receiptContentType = 'image/jpeg';
  bool _initialized = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _reference = TextEditingController();
    _phone = TextEditingController();
    _payerName = TextEditingController();
    _payerPhone = TextEditingController();
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _phone.dispose();
    _payerName.dispose();
    _payerPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _seedAmount(double debt, {String? phone, String? name}) {
    if (_initialized) return;
    _initialized = true;
    if (debt > 0) {
      _amount.text = debt.toStringAsFixed(2);
    }
    if (phone != null && phone.trim().isNotEmpty) {
      _phone.text = phone;
      _payerPhone.text = phone;
    }
    if (name != null && name.trim().isNotEmpty) {
      _payerName.text = name;
    }
  }

  String? get _amountError {
    if (!_attempted && _amount.text.trim().isEmpty) return null;
    return paymentAmountValidationMessage(_amount.text);
  }

  bool get _payerFeatureOn {
    final features = ref.read(authControllerProvider).session?.features;
    return features?.isCollectionPayerDetailsEnabled ?? true;
  }

  /// Who-paid / phone only after a non-cash method is selected.
  bool get _askPayer =>
      _payerFeatureOn && _method != PosPaymentMethod.cash;

  bool get _needsDestinationBeforeCode =>
      _payerFeatureOn &&
      _method == PosPaymentMethod.mpesa &&
      !isLiveMpesaPrompt(_mpesaCapture);

  bool get _codeUnlocked =>
      !_needsDestinationBeforeCode || _mpesaDestination.isNotEmpty;

  String? get _payerNameError {
    if (!_askPayer || (!_attempted && _payerName.text.trim().isEmpty)) {
      return null;
    }
    if (_payerName.text.trim().isEmpty) return 'Enter the name of who paid.';
    return null;
  }

  String? get _payerPhoneError {
    if (!_askPayer || (!_attempted && _payerPhone.text.trim().isEmpty)) {
      return null;
    }
    final digits = _payerPhone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter the phone number of who paid.';
    if (digits.length < 9) {
      return 'Enter a valid phone number (at least 9 digits).';
    }
    return null;
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    try {
      final prepared = ImageUploadGuard.prepare(
        bytes,
        preferredName: file.name,
      );
      setState(() {
        _receiptBytes = prepared.bytes;
        _receiptName = prepared.fileName;
        _receiptContentType = prepared.contentType;
      });
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _pickPaymentDate() async {
    final initial = DateTime.tryParse(_paymentDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _paymentDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _confirm() async {
    setState(() => _attempted = true);
    final amountError = paymentAmountValidationMessage(_amount.text);
    if (amountError != null) return;
    if (_askPayer) {
      if (_payerNameError != null || _payerPhoneError != null) return;
    }
    final amount = parsePaymentAmount(_amount.text)!;

    var reference = _reference.text;
    if (_method == PosPaymentMethod.mpesa) {
      if (_receiptBytes == null || _receiptBytes!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attach a screenshot of the M-Pesa repayment receipt.'),
          ),
        );
        return;
      }
      if (isLiveMpesaPrompt(_mpesaCapture)) {
        final phoneErr = phoneValidationMessage(_phone.text, required: true);
        if (phoneErr != null) return;
      } else {
        if (_needsDestinationBeforeCode && _mpesaDestination.isEmpty) {
          return;
        }
        if (mpesaReceiptValidationMessage(reference) != null) return;
        reference = normalizeMpesaReceipt(reference);
      }
    }

    final detail = ref.read(customerDetailProvider(widget.customerId)).detail;
    if (detail == null) return;

    final canApprove =
        ref.read(authControllerProvider).session?.permissions.canApproveDebtManagement ??
        false;
    final today = _todayLocalDate();
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
        CommitSummaryRow(label: 'Amount', value: formatKes(amount), emphasis: true),
        CommitSummaryRow(label: 'Method', value: _method.label),
        if (_askPayer && _payerName.text.trim().isNotEmpty)
          CommitSummaryRow(label: 'Paid by', value: _payerName.text.trim()),
        if (_askPayer && _payerPhone.text.trim().isNotEmpty)
          CommitSummaryRow(label: 'Payer phone', value: _payerPhone.text.trim()),
        if (_mpesaDestination.isNotEmpty)
          CommitSummaryRow(
            label: 'M-Pesa via',
            value: _mpesaDestination == 'bank' ? 'Bank' : 'Till',
          ),
        if (_method == PosPaymentMethod.mpesa &&
            isLiveMpesaPrompt(_mpesaCapture))
          CommitSummaryRow(label: 'Phone', value: _phone.text.trim())
        else if (reference.trim().isNotEmpty)
          CommitSummaryRow(
            label: _method == PosPaymentMethod.mpesa
                ? 'M-Pesa code'
                : 'Reference',
            value: reference.trim(),
          ),
        if (_paymentDate != today)
          CommitSummaryRow(label: 'Payment date', value: _paymentDate),
        if (_notes.text.trim().isNotEmpty)
          CommitSummaryRow(label: 'Notes', value: _notes.text.trim()),
        if (_receiptBytes != null)
          const CommitSummaryRow(label: 'Receipt', value: 'Attached'),
        if (detail.debtAmount > 0)
          CommitSummaryRow(
            label: 'Current debt',
            value: formatKes(detail.debtAmount),
          ),
      ],
      confirmLabel: 'Yes, record payment',
      cancelLabel: 'Back',
      confirmKey: const Key('settle_commit_confirm'),
      cancelKey: const Key('settle_commit_cancel'),
    );
    if (!confirmed || !mounted) return;

    if (_method == PosPaymentMethod.mpesa &&
        isLiveMpesaPrompt(_mpesaCapture)) {
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
          notes: _notes.text.trim(),
          payerName: _askPayer ? _payerName.text.trim() : '',
          payerPhone: _askPayer ? _payerPhone.text.trim() : '',
          mpesaDestination: _askPayer && _method == PosPaymentMethod.mpesa
              ? _mpesaDestination
              : '',
          paymentDate: _paymentDate != today ? _paymentDate : '',
          receiptImageBytes: _receiptBytes,
          receiptFileName: _receiptName,
          receiptContentType: _receiptContentType,
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
      _seedAmount(detail.debtAmount, phone: detail.phone, name: detail.name);
    }
    final askPayer = _askPayer;

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
                            _mpesaCapture = MpesaCaptureMode.code;
                            _mpesaDestination = '';
                          }
                        }),
                      ),
                  ],
                ),
                if (askPayer) ...[
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('settle_payer_name'),
                    controller: _payerName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Who paid *',
                      hintText: 'Name of the person who paid',
                      errorText: _payerNameError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('settle_payer_phone'),
                    controller: _payerPhone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Payer phone *',
                      hintText: '07… or +254…',
                      errorText: _payerPhoneError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('settle_payment_date'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment date'),
                  subtitle: Text(
                    _paymentDate == _todayLocalDate()
                        ? '$_paymentDate (today)'
                        : '$_paymentDate · past day',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickPaymentDate,
                ),
                if (_paymentDate != _todayLocalDate())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Marked as a past repayment on $_paymentDate.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                if (_method == PosPaymentMethod.mpesa) ...[
                  const SizedBox(height: 8),
                  Text(
                    'M-Pesa receipt screenshot *',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('settle_receipt_pick'),
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _receiptBytes == null
                          ? 'Attach receipt screenshot'
                          : 'Change receipt screenshot',
                    ),
                  ),
                  if (_receiptBytes != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _receiptBytes!,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ] else if (_attempted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Attach a screenshot of the M-Pesa repayment receipt.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_needsDestinationBeforeCode) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Did the payment come via till or bank?',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          key: const Key('settle_mpesa_via_till'),
                          label: const Text('Till'),
                          selected: _mpesaDestination == 'till',
                          onSelected: (_) => setState(() {
                            _mpesaDestination = 'till';
                          }),
                        ),
                        ChoiceChip(
                          key: const Key('settle_mpesa_via_bank'),
                          label: const Text('Bank'),
                          selected: _mpesaDestination == 'bank',
                          onSelected: (_) => setState(() {
                            _mpesaDestination = 'bank';
                          }),
                        ),
                      ],
                    ),
                    if (_attempted && _mpesaDestination.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Choose till or bank before entering the code.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                  if (_codeUnlocked) ...[
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
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('settle_notes'),
                  controller: _notes,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional — e.g. duka closed, partial visit',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
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
