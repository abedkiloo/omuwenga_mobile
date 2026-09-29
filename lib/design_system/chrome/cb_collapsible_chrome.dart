import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// True when the software keyboard (or a test view inset) is covering the page.
///
/// Reads both the inherited [MediaQuery] and the raw view so it still works
/// inside a [Scaffold] that already consumed `viewInsets` by resizing.
bool cbKeyboardInsetOpen(BuildContext context, {double threshold = 24}) {
  final inherited = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
  final view = View.maybeOf(context);
  final fromView = view == null
      ? 0.0
      : view.viewInsets.bottom / view.devicePixelRatio;
  return inherited > threshold || fromView > threshold;
}

/// Column layout for list pages whose chrome (filters/summaries) would
/// otherwise overflow on short phones, landscape, or when the keyboard is open.
///
/// Chrome is height-capped and scrolls. Search stays visible. Filter chips
/// hide while the keyboard is up so the field and list keep the remaining room.
class CbChromeListColumn extends StatelessWidget {
  const CbChromeListColumn({
    super.key,
    required this.chrome,
    required this.body,
    this.stickyBelow,
    this.filters,
    this.hideChromeWhenKeyboardVisible = true,
  });

  final Widget chrome;
  final Widget body;
  final Widget? stickyBelow;
  final Widget? filters;
  final bool hideChromeWhenKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = cbKeyboardInsetOpen(context);
    final hideChrome = hideChromeWhenKeyboardVisible && keyboardOpen;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chromeCap = math.max(72.0, constraints.maxHeight - 168);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hideChrome)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: chromeCap),
                child: ListView(
                  key: const Key('chrome_list_scroll'),
                  primary: false,
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [chrome],
                ),
              ),
            if (stickyBelow != null) stickyBelow!,
            if (filters != null && !keyboardOpen) filters!,
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

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
