import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/format/money.dart';
import '../../../core/media/proof_image_tile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../pos/domain/payment.dart';
import '../data/customers_api.dart';
import '../domain/payment_detail.dart';

/// Full payment review after a collection has been received (sale-detail style).
class PaymentDetailPage extends ConsumerStatefulWidget {
  const PaymentDetailPage({super.key, required this.paymentId});

  final int paymentId;

  @override
  ConsumerState<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends ConsumerState<PaymentDetailPage> {
  PaymentDetail? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = CustomersApi(ref.read(apiClientProvider));
    final result = await api.walletSettlementDetail(widget.paymentId);
    if (!mounted) return;
    result.when(
      success: (detail) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      },
      failure: (err, _) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _detail;
    final receiptUrl = detail == null
        ? ''
        : resolveMediaUrl(
            detail.receiptImageUrl,
            ref.watch(appEnvProvider).apiBaseUrl,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment detail'),
        leading: IconButton(
          key: const Key('payment_detail_back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : detail == null
                  ? const Center(child: Text('Payment not found.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        CbSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AMOUNT RECEIVED',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatKes(detail.amount),
                                key: const Key('payment_detail_amount'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                              if ((detail.occurredAt ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  detail.occurredAt!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                              if (detail.isBackdated)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Backdated',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        CbSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Meta(
                                label: 'Customer',
                                value: detail.customerName.isEmpty
                                    ? '—'
                                    : detail.customerName,
                                onTap: detail.customerId == null
                                    ? null
                                    : () => context.push(
                                          AppRoutes.customerDetail(
                                            detail.customerId!,
                                            tab: 'ledger',
                                          ),
                                        ),
                              ),
                              if ([
                                detail.customerPhone,
                                detail.customerCode,
                              ].any((s) => s.trim().isNotEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    [
                                      detail.customerPhone,
                                      detail.customerCode,
                                    ].where((s) => s.trim().isNotEmpty).join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                              const Divider(height: 22),
                              _Meta(label: 'Method', value: detail.methodDisplay),
                              const SizedBox(height: 10),
                              _Meta(label: 'Paid by', value: detail.payerDisplay),
                              const SizedBox(height: 10),
                              _Meta(
                                label: 'Reference',
                                value: detail.reference.trim().isEmpty
                                    ? '—'
                                    : detail.reference,
                              ),
                              const SizedBox(height: 10),
                              _Meta(
                                label: 'Collected by',
                                value: detail.receivedBy.trim().isEmpty
                                    ? '—'
                                    : detail.receivedBy,
                              ),
                              if (detail.notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _Meta(label: 'Notes', value: detail.notes),
                              ],
                              if (detail.previousDebt != null ||
                                  detail.newDebt != null) ...[
                                const SizedBox(height: 10),
                                _Meta(
                                  label: 'Debt trail',
                                  value: [
                                    if (detail.previousDebt != null)
                                      'Was ${formatKes(detail.previousDebt!)}',
                                    if (detail.newDebt != null)
                                      'Now ${formatKes(detail.newDebt!)}',
                                  ].join(' → '),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (detail.paidTowards.isNotEmpty ||
                            detail.paidTowardsLabel.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          CbSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PAID TOWARDS',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.mutedForeground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  detail.paidTowardsLabel.isNotEmpty
                                      ? detail.paidTowardsLabel
                                      : 'Customer debt',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                for (final t in detail.paidTowards) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    t.amount > 0
                                        ? '${t.label} · ${formatKes(t.amount)}'
                                        : t.label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        CbSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PAYMENT SCREENSHOT',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (receiptUrl.isNotEmpty)
                                ProofImageTile(
                                  url: receiptUrl,
                                  label: 'Payment screenshot',
                                )
                              else
                                Text(
                                  'No payment screenshot attached.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.mutedForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: onTap == null ? null : AppColors.primary,
            decoration: onTap == null ? null : TextDecoration.underline,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}
