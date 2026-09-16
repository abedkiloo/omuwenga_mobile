import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds receipt PDF locally on request', () async {
    final receipt = SaleReceipt(
      id: 7,
      saleNumber: 'SALE-7',
      total: 116,
      subtotal: 120,
      taxAmount: 6,
      discountAmount: 10,
      paymentMethod: 'mpesa',
      paymentReference: 'MPESA-REF',
      amountPaid: 116,
      change: 0,
      createdAt: DateTime.utc(2026, 9, 16, 12, 30),
      customerName: 'Test Customer',
      items: const [
        CartLine(productId: 1, name: 'Test Item', unitPrice: 60, quantity: 2),
      ],
    );

    final bytes = await buildReceiptPdf(receipt);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(receiptFileName(receipt), 'receipt-SALE-7.pdf');
  });
}
