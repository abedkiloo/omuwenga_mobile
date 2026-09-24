import 'package:flutter/material.dart';

/// Keyboard-safe height for a modal sheet. Do not pad by [viewInsets]
/// and also subtract them from height — that double-counts and overflows.
double cbSheetFrameHeight({
  required double mediaHeight,
  required double inset,
  required double maxConstraintHeight,
  required double heightFactor,
}) {
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
  });

  final Widget child;
  final double heightFactor;

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
      final sheet = CbSheetFrame(
        heightFactor: heightFactor,
        child: builder(ctx),
      );
      if (inset <= 0) return sheet;
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: sheet,
        ),
      );
    },
  );
}
