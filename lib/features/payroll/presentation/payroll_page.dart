import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/result/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../application/payroll_controller.dart';
import '../domain/payroll.dart';
import 'payslip_preview_page.dart';

class PayrollPage extends ConsumerStatefulWidget {
  const PayrollPage({super.key});

  @override
  ConsumerState<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends ConsumerState<PayrollPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(payrollProvider.notifier).load();
    });
  }

  Future<void> _previewPdf(MyPayslipSummary slip) async {
    final result =
        await ref.read(payrollProvider.notifier).downloadPayslipPdf(slip.id);
    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((result as Failure).error.toString()),
        ),
      );
      return;
    }
    final bytes = result.getOrThrow();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PayslipPreviewPage(slip: slip, bytes: bytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollProvider);
    final pay = state.pay;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My pay')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(payrollProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (state.loading && pay == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (pay == null || !pay.linked) ...[
              EmptyState(
                title: 'No pay record yet',
                message: pay?.detail ??
                    'Ask HR to link your staff profile to this account email.',
                primaryLabel: 'Refresh',
                onPrimary: () => ref.read(payrollProvider.notifier).load(),
              ),
            ] else ...[
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                pay.name.isEmpty ? 'Your current pay' : pay.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pay.staffCode.isNotEmpty || pay.position.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (pay.staffCode.isNotEmpty) pay.staffCode,
                    if (pay.position.isNotEmpty) pay.position,
                    if (pay.roleName != null && pay.roleName!.isNotEmpty)
                      pay.roleName,
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _TotalsCard(pay: pay),
              if (pay.packageName != null && pay.packageName!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  pay.inheritsPackage
                      ? 'From package: ${pay.packageName}'
                      : 'Package: ${pay.packageName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              if (pay.earnings.isNotEmpty) ...[
                const SizedBox(height: 20),
                const CbSectionLabel(
                  label: 'Earnings',
                  icon: Icons.trending_up_outlined,
                ),
                const SizedBox(height: 8),
                for (final line in pay.earnings) _PayLineTile(line: line),
              ],
              if (pay.deductions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const CbSectionLabel(
                  label: 'Deductions',
                  icon: Icons.trending_down_outlined,
                ),
                const SizedBox(height: 8),
                for (final line in pay.deductions) _PayLineTile(line: line),
              ],
              const SizedBox(height: 24),
              const CbSectionLabel(
                label: 'Locked payslips',
                icon: Icons.description_outlined,
              ),
              const SizedBox(height: 8),
              if (state.payslips.isEmpty)
                Text(
                  'No locked payslips yet. They appear here after payroll is approved for the period.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                )
              else
                for (final slip in state.payslips)
                  _PayslipTile(
                    slip: slip,
                    downloading: state.downloadingId == slip.id,
                    onOpen: () => _previewPdf(slip),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.pay});
  final MyCurrentPay pay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated net',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatKes(pay.estimatedNet),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Basic',
                  value: formatKes(pay.effectiveBasic),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Gross',
                  value: formatKes(pay.estimatedGross),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Deductions',
                  value: formatKes(pay.estimatedDeductions),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Preview from your role package and staff-pay edits. Statutory and loan items appear on locked payslips.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PayLineTile extends StatelessWidget {
  const _PayLineTile({required this.line});
  final PayLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.bodyMedium),
                if (line.source.isNotEmpty)
                  Text(
                    line.source,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatKes(line.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayslipTile extends StatelessWidget {
  const _PayslipTile({
    required this.slip,
    required this.downloading,
    required this.onOpen,
  });

  final MyPayslipSummary slip;
  final bool downloading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(slip.period),
      subtitle: Text(
        'Net ${formatKes(slip.netPay)} · Gross ${formatKes(slip.grossPay)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.mutedForeground,
        ),
      ),
      trailing: downloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              key: Key('payslip_preview_${slip.id}'),
              tooltip: 'Preview payslip',
              onPressed: onOpen,
              icon: const Icon(Icons.visibility_outlined),
            ),
    );
  }
}
