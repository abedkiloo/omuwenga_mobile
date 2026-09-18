import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shared filter / period chip used across lists (sales dates, debtors, etc.).
///
/// Selected = solid primary (clear “where am I?” signal).
/// Idle = soft surface + border (low visual noise, easy to scan).
class CbFilterChip extends StatelessWidget {
  const CbFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primaryForeground : AppColors.foreground;
    final bg = selected ? AppColors.primary : AppColors.surface;
    final border = selected ? AppColors.primary : AppColors.border;

    final child = Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          alignment: expand ? Alignment.center : null,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: expand
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: 15),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              if (expand)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      height: 1.1,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return child;
  }
}

