import 'package:flutter/material.dart';

/// Single-line text that ellipsizes instead of overflowing a tight row.
class CbEllipsisText extends StatelessWidget {
  const CbEllipsisText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: maxLines > 1,
      textAlign: textAlign,
      style: style,
    );
  }
}

/// Amounts that shrink to fit instead of overflowing the row.
class CbFitMoney extends StatelessWidget {
  const CbFitMoney(
    this.text, {
    super.key,
    this.style,
    this.alignment = Alignment.centerRight,
  });

  final String text;
  final TextStyle? style;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}
