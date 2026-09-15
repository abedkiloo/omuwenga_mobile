import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../application/payment_controllers.dart';
import '../domain/payment_intent.dart';

/// Calm waiting UI — money is real only when server says paid.
class StkWaitPage extends ConsumerStatefulWidget {
  const StkWaitPage({
    super.key,
    required this.amount,
    required this.phone,
    required this.purpose,
    this.customerId,
    this.customerName = '',
  });

  final double amount;
  final String phone;
  final String purpose;
  final int? customerId;
  final String customerName;

  @override
  ConsumerState<StkWaitPage> createState() => _StkWaitPageState();
}

class _StkWaitPageState extends ConsumerState<StkWaitPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stkWaitProvider.notifier).start(
            amount: widget.amount,
            phone: widget.phone,
            purpose: widget.purpose,
            customerId: widget.customerId,
            customerName: widget.customerName,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stkWaitProvider);
    final intent = state.intent;
    final theme = Theme.of(context);

    String title;
    String body;
    CbStatusPillVariant statusVariant;
    if (state.offlineBlocked) {
      title = 'Offline';
      body = state.error ?? 'Connect to send an M-Pesa prompt.';
      statusVariant = CbStatusPillVariant.warning;
    } else if (state.isPaid) {
      title = 'Payment confirmed';
      body = intent?.smsSent == true
          ? 'SMS receipt queued/sent with invoice link.'
          : 'M-Pesa confirmed on the server.';
      statusVariant = CbStatusPillVariant.success;
    } else if (state.isFailed) {
      title = 'Payment not completed';
      body = intent?.failureReason?.isNotEmpty == true
          ? intent!.failureReason!
          : 'Customer cancelled or prompt expired.';
      statusVariant = CbStatusPillVariant.warning;
    } else {
      title = 'Waiting for M-Pesa';
      body =
          'We asked ${widget.phone} to pay KES ${widget.amount.toStringAsFixed(2)}. '
          'Money is real only when confirmed.';
      statusVariant = CbStatusPillVariant.info;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('M-Pesa prompt'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CbSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CbStatusPill(label: title, variant: statusVariant),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    key: const Key('stk_title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    key: const Key('stk_body'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  if (state.polling) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: CircularProgressIndicator(key: Key('stk_spinner')),
                    ),
                  ],
                  if (state.isPaid && state.showSmsSent)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'SMS sent',
                        key: Key('stk_sms_sent'),
                        style: TextStyle(color: AppColors.success),
                      ),
                    ),
                  if (state.error != null && !state.offlineBlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.error!,
                        key: const Key('stk_error'),
                        style: const TextStyle(color: AppColors.destructive),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            if (!state.isPaid && !state.offlineBlocked)
              CbPrimaryButton(
                key: const Key('stk_query'),
                label: 'Check status',
                onPressed: state.polling && intent == null
                    ? null
                    : () => ref.read(stkWaitProvider.notifier).queryNow(),
              ),
            const SizedBox(height: 8),
            CbPrimaryButton(
              key: const Key('stk_done'),
              label: state.isPaid ? 'Done' : 'Close',
              onPressed: () => Navigator.of(context).maybePop(
                state.isPaid ? intent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<PaymentIntent?> showStkWaitSheet(
  BuildContext context, {
  required double amount,
  required String phone,
  required String purpose,
  int? customerId,
  String customerName = '',
}) {
  return Navigator.of(context).push<PaymentIntent?>(
    MaterialPageRoute(
      builder: (_) => StkWaitPage(
        amount: amount,
        phone: phone,
        purpose: purpose,
        customerId: customerId,
        customerName: customerName,
      ),
    ),
  );
}
