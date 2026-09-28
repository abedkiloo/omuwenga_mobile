import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../domain/appraisal.dart';

class AppraisalProgressCard extends StatelessWidget {
  const AppraisalProgressCard({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final AppraisalSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = snapshot.today.tone;
    return CbSurfaceCard(
      key: const Key('appraisal_progress_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snapshot.headline.isEmpty
                      ? '5-star progress'
                      : snapshot.headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.starTone(tone),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                starGlyphs(snapshot.today.stars),
                style: TextStyle(
                  color: AppColors.starTone(tone),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!compact && snapshot.detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(snapshot.detail, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          _Bar(
            label:
                'Today KES ${snapshot.today.sales.round()} / ${snapshot.today.target.round()}',
            progress: snapshot.today.targetProgress,
            tone: snapshot.today.tone,
          ),
          const SizedBox(height: 8),
          _Bar(
            label:
                'Month avg ${snapshot.month.officialAverage.toStringAsFixed(2)}/5 · bonus KES ${snapshot.month.bonus.round()}',
            progress: snapshot.month.progressToFourStar,
            tone: snapshot.month.fourStarMonth ? 'emerald' : snapshot.month.tone,
          ),
          const SizedBox(height: 8),
          _Bar(
            label:
                'Year ${snapshot.year.fourStarMonths}/${snapshot.year.fourStarMonthsRequired} four-star months',
            progress: snapshot.year.progressToIncrement,
            tone: snapshot.year.qualifies ? 'gold' : snapshot.year.tone,
          ),
          if (compact) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.appraisals),
                child: const Text('Open full appraisal'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.progress,
    required this.tone,
  });

  final String label;
  final double progress;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final width = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                const ColoredBox(color: AppColors.secondary, child: SizedBox.expand()),
                FractionallySizedBox(
                  widthFactor: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: AppColors.starGradient(tone)),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
