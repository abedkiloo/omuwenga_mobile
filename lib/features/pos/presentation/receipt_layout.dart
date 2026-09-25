import '../../../core/branding/brand_assets.dart';
import '../data/pos_api.dart';
import '../domain/cart.dart';
import '../domain/payment.dart';

const kDefaultReceiptStoreName = BrandAssets.appName;
const kDefaultReceiptFooter = 'Thank you for your business!';
const kReceiptReachUsPhone = '0718515142';
const kReceiptReachUsLabel = 'You can reach us via $kReceiptReachUsPhone';

/// Store / branch branding used on the shared thermal receipt (matches web).
class ReceiptStoreInfo {
  const ReceiptStoreInfo({
    this.storeName = kDefaultReceiptStoreName,
    this.branchName = '',
    this.address = '',
    this.phone = '',
    this.taxId = '',
    this.header = '',
    this.footer = kDefaultReceiptFooter,
    this.showSku = false,
  });

  final String storeName;
  final String branchName;
  final String address;
  final String phone;
  final String taxId;
  final String header;
  final String footer;
  final bool showSku;

  factory ReceiptStoreInfo.fromPosSettings(PosSettings settings) {
    return ReceiptStoreInfo(
      storeName: settings.storeName.trim().isEmpty
          ? kDefaultReceiptStoreName
          : settings.storeName.trim(),
      branchName: settings.branchName.trim(),
      address: settings.address.trim(),
      phone: settings.phone.trim(),
      taxId: settings.taxId.trim(),
      header: settings.receiptHeader.trim(),
      footer: settings.receiptFooter.trim().isEmpty
          ? kDefaultReceiptFooter
          : settings.receiptFooter.trim(),
      showSku: settings.showSku,
    );
  }
}

String formatReceiptMoney(num value) {
  final n = value.toDouble();
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final whole = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    if (i > 0 && remaining % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  return '${sign}Ksh ${grouped.toString()}.${parts[1]}';
}

String formatReceiptDate(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatReceiptQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String receiptPaymentLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'cash':
      return 'Cash';
    case 'mpesa':
      return 'M-Pesa';
    case 'wallet':
      return 'Wallet';
    case 'card':
      return 'Card';
    case 'bank_transfer':
      return 'Bank Transfer';
    default:
      return raw.trim().isEmpty ? 'Paid' : raw.trim();
  }
}

double receiptSubtotal(SaleReceipt receipt) {
  return receipt.subtotal ??
      receipt.items.fold<double>(0, (sum, line) => sum + line.lineTotal);
}

double receiptBalanceOwed(SaleReceipt receipt) {
  final due = receipt.total - receipt.amountPaid;
  return due < 0 ? 0 : due;
}

bool receiptShowsChange(SaleReceipt receipt) {
  final method = receipt.paymentMethod.trim().toLowerCase();
  return (method == 'cash' || method == 'mpesa') && receipt.change > 0;
}

String receiptItemName(CartLine line) => line.name;

String? receiptItemVariant(CartLine line) {
  final label = line.variantLabel?.trim();
  if (label == null || label.isEmpty) return null;
  return label;
}

String receiptItemQtyLine(CartLine line) {
  return '  ${formatReceiptQuantity(line.quantity)} × ${formatReceiptMoney(line.unitPrice)}';
}

/// Plain-text thermal receipt used for WhatsApp / SMS share, matching web.
String buildThermalReceiptText(
  SaleReceipt receipt, {
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
}) {
  final lines = <String>[];
  void blank() => lines.add('');
  void rule([String ch = '-']) => lines.add(List.filled(32, ch).join());
  void pair(String left, String right) {
    final gap = 32 - left.length - right.length;
    if (gap < 1) {
      lines.add(left);
      lines.add(right.padLeft(32));
      return;
    }
    lines.add('$left${' ' * gap}$right');
  }

  lines.add(store.storeName.toUpperCase());
  if (store.header.isNotEmpty) lines.add(store.header);
  if (store.branchName.isNotEmpty &&
      store.branchName.toLowerCase() != store.storeName.toLowerCase()) {
    lines.add(store.branchName);
  }
  if (store.address.isNotEmpty) lines.add(store.address);
  if (store.phone.isNotEmpty) lines.add(store.phone);
  if (store.taxId.isNotEmpty) lines.add('PIN: ${store.taxId}');
  blank();
  rule('=');
  pair('Receipt', receipt.saleNumber.isEmpty ? '—' : receipt.saleNumber);
  final date = formatReceiptDate(receipt.createdAt);
  if (date.isNotEmpty) pair('Date', date);
  final served = receipt.servedByName?.trim() ?? '';
  if (served.isNotEmpty) pair('Served by', served);
  rule();
  if (receipt.items.isEmpty) {
    lines.add('No items.');
  } else {
    for (final line in receipt.items) {
      final variant = receiptItemVariant(line);
      lines.add(
        variant == null
            ? receiptItemName(line)
            : '${receiptItemName(line)} ($variant)',
      );
      if (store.showSku) {
        final sku = line.sku?.trim() ?? '';
        if (sku.isNotEmpty) lines.add(sku);
      }
      pair(receiptItemQtyLine(line), formatReceiptMoney(line.lineTotal));
    }
  }
  rule();
  pair('Subtotal', formatReceiptMoney(receiptSubtotal(receipt)));
  if (receipt.discountAmount > 0) {
    pair('Discount', '-${formatReceiptMoney(receipt.discountAmount)}');
  }
  if (receipt.taxAmount > 0) {
    final vatLabel = receipt.taxRate > 0
        ? 'VAT (${receipt.taxRate.toStringAsFixed(0)}%)'
        : 'VAT';
    pair(vatLabel, formatReceiptMoney(receipt.taxAmount));
  }
  if (receipt.deliveryCost > 0) {
    pair('Delivery', formatReceiptMoney(receipt.deliveryCost));
  }
  rule('=');
  pair('TOTAL', formatReceiptMoney(receipt.total));
  rule('=');
  pair(
    receiptPaymentLabel(receipt.paymentMethod),
    formatReceiptMoney(receipt.amountPaid),
  );
  final reference = receipt.paymentReference?.trim() ?? '';
  if (reference.isNotEmpty) pair('Ref', reference);
  if (receiptShowsChange(receipt)) {
    pair('Change', formatReceiptMoney(receipt.change));
  }
  final owed = receiptBalanceOwed(receipt);
  if (owed > 0.005) {
    pair('Balance (owed)', formatReceiptMoney(owed));
  }
  if (receipt.paymentMethod.trim().toLowerCase() == 'wallet') {
    lines.add('Paid from customer wallet.');
  }
  rule();
  lines.add(store.footer);
  lines.add(kReceiptReachUsLabel);
  if (receipt.saleNumber.isNotEmpty) lines.add(receipt.saleNumber);
  return lines.join('\n');
}
