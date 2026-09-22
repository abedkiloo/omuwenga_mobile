import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

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
      servedByName: 'Amina',
      items: const [
        CartLine(productId: 1, name: 'Test Item', unitPrice: 60, quantity: 2),
      ],
    );

    final bytes = await buildReceiptPdf(receipt);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(receiptFileName(receipt), 'receipt-SALE-7.pdf');
    expect(kReceiptReachUsPhone, '0718515142');
    expect(kReceiptReachUsLabel, 'You can reach us via 0718515142');
    final format = receiptPdfPageFormat();
    expect(format.width, closeTo(52 * PdfPageFormat.mm, 0.01));
    expect(format.height, double.infinity);
  });

  test('reads served by from API payload', () {
    final fromServed = SaleReceipt.fromJson({
      'id': 1,
      'sale_number': 'S-1',
      'total': 10,
      'payment_method': 'cash',
      'amount_paid': 10,
      'change': 0,
      'served_by_name': 'Amina',
      'cashier_name': 'Kai',
      'items': [],
    });
    expect(fromServed.servedByName, 'Amina');

    final fromCashier = SaleReceipt.fromJson({
      'id': 2,
      'sale_number': 'S-2',
      'total': 10,
      'payment_method': 'cash',
      'amount_paid': 10,
      'change': 0,
      'cashier_name': 'Kai',
      'items': [],
    });
    expect(fromCashier.servedByName, 'Kai');
  });
}
