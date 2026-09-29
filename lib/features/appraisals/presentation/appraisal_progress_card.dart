import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/appraisal.dart';

class AppraisalProgressCard extends StatelessWidget {
  const AppraisalProgressCard({
    super.key,
    required this.snapshot,
    this.compact = false,
    this.emphasis = false,
    this.footer,
  });

  final AppraisalSnapshot snapshot;
  final bool compact;
  final bool emphasis;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tone = snapshot.today.tone;
    final accent = AppColors.starTone(tone);
    final pad = emphasis ? 20.0 : 16.0;

    return Container(
      key: const Key('appraisal_progress_card'),
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.starPanel(tone),
        borderRadius: BorderRadius.circular(emphasis ? 20 : 14),
        border: Border.all(
          color: accent.withValues(alpha: emphasis ? 0.9 : 0.55),
          width: emphasis ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: emphasis ? 28 : 12,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withValues(alpha: emphasis ? 0.35 : 0.18),
            blurRadius: emphasis ? 24 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR PROGRESS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  snapshot.headline.isEmpty
                      ? 'Target delivery'
                      : snapshot.headline,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: emphasis ? 22 : 18,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                starGlyphs(snapshot.today.stars),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: emphasis ? 22 : 18,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: 0.7), blurRadius: 12),
                  ],
                ),
              ),
            ],
          ),
          if (!compact && snapshot.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              snapshot.detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: emphasis ? 14 : 13,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: emphasis ? 16 : 12),
          _Bar(
            label:
                'Today KES ${snapshot.today.sales.round()} of ${snapshot.today.target.round()} daily target',
            progress: snapshot.today.targetProgress,
            tone: snapshot.today.tone,
            thick: emphasis,
          ),
          const SizedBox(height: 10),
          _Bar(
            label:
                'This month ${snapshot.month.officialAverage.toStringAsFixed(2)}/5 toward a 4-star month',
            progress: snapshot.month.progressToFourStar,
            tone: snapshot.month.fourStarMonth ? 'emerald' : snapshot.month.tone,
            thick: emphasis,
          ),
          if (snapshot.showYearEndIncrement) ...[
            const SizedBox(height: 10),
            _Bar(
              label:
                  'Year ${snapshot.year.fourStarMonths}/${snapshot.year.fourStarMonthsRequired} four-star months',
              progress: snapshot.year.progressToIncrement,
              tone: snapshot.year.qualifies ? 'gold' : snapshot.year.tone,
              thick: emphasis,
            ),
          ],
          if (snapshot.todayTips.tips.isNotEmpty) ...[
            SizedBox(height: emphasis ? 16 : 12),
            _DailyTips(pack: snapshot.todayTips, compact: compact, emphasis: emphasis),
          ],
          if (compact) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.appraisals),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Open my progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
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
    this.thick = false,
  });

  final String label;
  final double progress;
  final String tone;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    final width = progress.clamp(0.0, 1.0);
    final accent = AppColors.starTone(tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: thick ? 16 : 12,
            child: Stack(
              children: [
                const ColoredBox(
                  color: Color(0x33FFFFFF),
                  child: SizedBox.expand(),
                ),
                FractionallySizedBox(
                  widthFactor: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.starGradient(tone),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 8,
                        ),
                      ],
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

class _DailyTips extends StatelessWidget {
  const _DailyTips({
    required this.pack,
    required this.compact,
    required this.emphasis,
  });

  final AppraisalTipPack pack;
  final bool compact;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'Today’s move: ',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
            TextSpan(
              text: pack.tips.first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                height: 1.35,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13),
      );
    }

    return Container(
      key: const Key('appraisal_daily_tips'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW TO HIT TODAY’S TARGET',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pack.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (pack.why.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              pack.why,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < pack.tips.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: emphasis ? const Color(0xFFFBBF24) : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: emphasis ? const Color(0xFF0F172A) : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pack.tips[i],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
