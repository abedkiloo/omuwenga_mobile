/// Copy that explains sale corrections before a cashier confirms them.
class SaleActionHelp {
  const SaleActionHelp({
    required this.shortLabel,
    required this.title,
    required this.body,
    required this.contrast,
  });

  final String shortLabel;
  final String title;
  final String body;
  final String contrast;

  static const refund = SaleActionHelp(
    shortLabel: 'Void / refund',
    title: 'Void or refund a sale',
    body:
        'Use this when a customer returns goods, or you need to reverse some or all of a real sale. You can refund the whole receipt or selected lines. The original sale stays on record.',
    contrast:
        'Not for a cashier mistake. Roll back is for duplicate or wrong-till sales.',
  );

  static const rollback = SaleActionHelp(
    shortLabel: 'Roll back sale',
    title: 'Roll back a mistaken sale',
    body:
        'Use this when the sale should never have been recorded — duplicate checkout, wrong till, or wrong customer. It always reverses the whole sale and needs admin approval.',
    contrast:
        'Not for a customer return. Void / refund is for goods coming back.',
  );
}
