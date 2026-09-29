import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../application/appraisals_controller.dart';
import '../domain/appraisal.dart';
import 'appraisal_progress_card.dart';

class AppraisalsPage extends ConsumerStatefulWidget {
  const AppraisalsPage({super.key});

  @override
  ConsumerState<AppraisalsPage> createState() => _AppraisalsPageState();
}

class _AppraisalsPageState extends ConsumerState<AppraisalsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appraisalsProvider.notifier).load();
    });
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appraisalsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Target delivery')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appraisalsProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (state.loading && state.snapshot == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.snapshot == null)
              EmptyState(
                title: 'No target delivery yet',
                message: 'Closed sales fill your daily stars. Use today’s five moves to follow up, talk well, and win more customers.',
                primaryLabel: 'Refresh',
                onPrimary: () => ref.read(appraisalsProvider.notifier).load(),
              )
            else ...[
              AppraisalProgressCard(snapshot: state.snapshot!, emphasis: true),
              if (state.snapshot!.showYearEndIncrement) ...[
                const SizedBox(height: 16),
                const CbSectionLabel(label: 'This year', icon: Icons.calendar_month_outlined),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final month in state.snapshot!.year.months)
                      _MonthChip(month: month, label: _months[(month.month - 1).clamp(0, 11)]),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month, required this.label});

  final AppraisalMonthSlice month;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.starTone(month.tone);
    return Container(
      width: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.starPanel(month.tone),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          Text(
            month.officialAverage.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            month.fourStarMonth ? '4★' : '—',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
