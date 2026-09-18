import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Scroll-aware chrome that collapses to a thin bar with a caret so list
/// content gets more vertical room. Tap the caret to restore filters/summaries.
class CbCollapsibleChrome extends StatelessWidget {
  const CbCollapsibleChrome({
    super.key,
    required this.collapsed,
    required this.onToggle,
    required this.collapsedLabel,
    required this.child,
    this.collapsedSummary,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final String collapsedLabel;
  final Widget child;
  final String? collapsedSummary;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: collapsed
          ? _CollapsedBar(
              label: collapsedLabel,
              summary: collapsedSummary,
              onExpand: onToggle,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    key: const Key('chrome_collapse'),
                    onPressed: onToggle,
                    icon: const Icon(Icons.expand_less, size: 18),
                    label: const Text('Hide details'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({
    required this.label,
    required this.onExpand,
    this.summary,
  });

  final String label;
  final String? summary;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: const Key('chrome_expand'),
        onTap: onExpand,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (summary != null && summary!.isNotEmpty)
                      Text(
                        summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Show details',
                onPressed: onExpand,
                icon: const Icon(Icons.expand_more),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapses chrome when the user scrolls a list down; restores near the top.
bool handleChromeScrollCollapse({
  required ScrollNotification notification,
  required bool collapsed,
  required ValueChanged<bool> setCollapsed,
  double collapseAfterPixels = 36,
}) {
  if (notification is! ScrollUpdateNotification) return false;
  final delta = notification.scrollDelta ?? 0;
  final pixels = notification.metrics.pixels;
  if (!collapsed && delta > 2 && pixels > collapseAfterPixels) {
    setCollapsed(true);
  } else if (collapsed && delta < -2 && pixels <= 8) {
    setCollapsed(false);
  }
  return false;
}
