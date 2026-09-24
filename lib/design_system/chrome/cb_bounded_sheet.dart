import 'package:flutter/material.dart';

/// Keyboard-safe height for a modal sheet. Do not pad by [viewInsets]
/// and also subtract them from height — that double-counts and overflows.
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
    final maxHeight = (size.height - inset).clamp(200.0, size.height);
    return SizedBox(
      height: (maxHeight * heightFactor).clamp(200.0, maxHeight),
      child: child,
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
    builder: (ctx) => CbSheetFrame(
      heightFactor: heightFactor,
      child: builder(ctx),
    ),
  );
}
