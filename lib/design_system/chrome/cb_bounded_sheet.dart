import 'package:flutter/material.dart';

/// Keyboard-safe height for a modal sheet.
///
/// Prefer a **stable** frame ([shrinkForKeyboard] = false): keep
/// `mediaHeight * heightFactor` and lift content with bottom padding for the
/// keyboard. Shrinking the whole sheet when the keyboard opens (or when a
/// dropdown dismisses it) causes a jump.
double cbSheetFrameHeight({
  required double mediaHeight,
  required double inset,
  required double maxConstraintHeight,
  required double heightFactor,
  bool shrinkForKeyboard = false,
}) {
  final base = mediaHeight * heightFactor;
  if (!shrinkForKeyboard) {
    if (!maxConstraintHeight.isFinite) return base.clamp(0.0, mediaHeight);
    return base.clamp(0.0, maxConstraintHeight);
  }
  final mqUsable = (mediaHeight - inset).clamp(0.0, mediaHeight);
  final double usable;
  if (!maxConstraintHeight.isFinite) {
    usable = mqUsable;
  } else if (maxConstraintHeight <= mqUsable + 0.5) {
    usable = maxConstraintHeight;
  } else {
    usable = mqUsable.clamp(0.0, maxConstraintHeight);
  }
  if (usable <= 0) return 0;
  return (usable * heightFactor).clamp(0.0, usable);
}

class CbSheetFrame extends StatelessWidget {
  const CbSheetFrame({
    super.key,
    required this.child,
    this.heightFactor = 0.92,
    this.shrinkForKeyboard = false,
  });

  final Widget child;
  final double heightFactor;

  /// When true, sheet height shrinks with the keyboard (legacy). Prefer false
  /// so dropdowns / focus changes do not jump the sheet.
  final bool shrinkForKeyboard;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: cbSheetFrameHeight(
            mediaHeight: size.height,
            inset: inset,
            maxConstraintHeight: constraints.maxHeight,
            heightFactor: heightFactor,
            shrinkForKeyboard: shrinkForKeyboard,
          ),
          child: child,
        );
      },
    );
  }
}

Future<T?> showCbBoundedSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double heightFactor = 0.92,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    showDragHandle: showDragHandle,
    useSafeArea: true,
    builder: (ctx) {
      final inset = MediaQuery.viewInsetsOf(ctx).bottom;
      // Stable sheet height + bottom pad for keyboard — avoids jump when
      // dropdowns dismiss the keyboard or fields scroll into view.
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: CbSheetFrame(
            heightFactor: heightFactor,
            shrinkForKeyboard: false,
            child: builder(ctx),
          ),
        ),
      );
    },
  );
}
