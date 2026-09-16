import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CbStepProgress extends StatelessWidget {
  const CbStepProgress({
    super.key,
    required this.labels,
    required this.currentIndex,
  });

  final List<String> labels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 13),
                  child: Container(
                    height: 2,
                    color: i <= currentIndex
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepCircle(
                  index: i + 1,
                  completed: i < currentIndex,
                  active: i == currentIndex,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 68,
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle?.copyWith(
                      color: i <= currentIndex
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                      fontWeight: i == currentIndex
                          ? FontWeight.w600
                          : FontWeight.w500,
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

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.index,
    required this.completed,
    required this.active,
  });

  final int index;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final done = completed || active;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.primary : AppColors.secondary,
        shape: BoxShape.circle,
      ),
      child: completed
          ? const Icon(
              Icons.check,
              size: 16,
              color: AppColors.primaryForeground,
            )
          : Text(
              '$index',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: done
                    ? AppColors.primaryForeground
                    : AppColors.mutedForeground,
              ),
            ),
    );
  }
}
