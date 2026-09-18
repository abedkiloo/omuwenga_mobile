import 'package:flutter/material.dart';

/// Shared page insets — keep chrome tight so lists and cards fill the screen.
abstract final class AppSpacing {
  static const double pageX = 12;
  static const double pageY = 8;
  static const double section = 8;
  static const double card = 12;
  static const double listGap = 6;

  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: pageX,
    vertical: pageY,
  );

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: pageX,
  );

  static EdgeInsets pageTop([double top = pageY]) =>
      EdgeInsets.fromLTRB(pageX, top, pageX, 0);

  static EdgeInsets listPadding({
    double top = section,
    double bottom = pageY,
  }) => EdgeInsets.fromLTRB(pageX, top, pageX, bottom);
}
