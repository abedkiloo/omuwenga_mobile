import 'dart:async';

import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_document.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_layout.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_page.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/thermal_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

SaleReceipt _receipt({
  String saleNumber = 'SALE-7',
  String paymentMethod = 'mpesa',
  double total = 116,
  double amountPaid = 116,
  double change = 0,
  double taxAmount = 6,
  double taxRate = 16,
  double discountAmount = 10,
  double deliveryCost = 0,
  String? paymentReference = 'MPESA-REF',
  String? servedByName = 'Amina',
  String? customerName = 'Test Customer',
  List<CartLine>? items,
}) {
  return SaleReceipt(
    id: 7,
    saleNumber: saleNumber,
    total: total,
    subtotal: 120,
    taxAmount: taxAmount,
    taxRate: taxRate,
    discountAmount: discountAmount,
    deliveryCost: deliveryCost,
    paymentMethod: paymentMethod,
    paymentReference: paymentReference,
    amountPaid: amountPaid,
    change: change,
    createdAt: DateTime.utc(2026, 9, 16, 12, 30),
    customerName: customerName,
    servedByName: servedByName,
    items:
        items ??
        const [
          CartLine(
            productId: 1,
            name: 'Test Item',
            sku: 'SKU-1',
            unitPrice: 60,
            quantity: 2,
            variantLabel: 'Large',
          ),
        ],
  );
}

void main() {
  test('builds receipt PDF locally on request', () async {
    final receipt = _receipt();
    const store = ReceiptStoreInfo(
      storeName: 'Test Duka',
      header: 'Licensed retailer',
      branchName: 'Westlands',
      address: 'Nairobi',
      phone: '0700000000',
      taxId: 'P051234',
      footer: 'Asante kwa biashara yako.',
      showSku: true,
    );

    final bytes = await buildReceiptPdf(receipt, store: store);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(receiptFileName(receipt), 'receipt-SALE-7.pdf');
    expect(kReceiptReachUsPhone, '0718515142');
    expect(kReceiptReachUsLabel, 'You can reach us via 0718515142');
    final format = receiptPdfPageFormat();
    expect(format.width, closeTo(80 * PdfPageFormat.mm, 0.01));
    expect(format.height, double.infinity);
  });

  test('thermal share text matches the web receipt layout', () {
    final text = buildThermalReceiptText(
      _receipt(deliveryCost: 50, change: 4, amountPaid: 120),
      store: const ReceiptStoreInfo(
        storeName: 'Test Duka',
        header: 'Welcome',
        branchName: 'Westlands',
        address: 'Nairobi',
        phone: '0700',
        taxId: 'P051',
        showSku: true,
      ),
    );

    expect(text, contains('TEST DUKA'));
    expect(text, contains('Welcome'));
    expect(text, contains('Westlands'));
    expect(text, contains('PIN: P051'));
    expect(text, contains('Receipt'));
    expect(text, contains('SALE-7'));
    expect(text, contains('16/09/2026'));
    expect(text, contains('Served by'));
    expect(text, contains('Test Item (Large)'));
    expect(text, contains('SKU-1'));
    expect(text, contains('2 ×'));
    expect(text, contains('Subtotal'));
    expect(text, contains('Discount'));
    expect(text, contains('VAT (16%)'));
    expect(text, contains('Delivery'));
    expect(text, contains('TOTAL'));
    expect(text, contains('M-Pesa'));
    expect(text, contains('Ref'));
    expect(text, contains('Change'));
    expect(text, contains('Thank you for your business!'));
    expect(text, contains(kReceiptReachUsLabel));
    expect(text, isNot(contains('TOTAL NET')));
    expect(text, isNot(contains('SALE RECEIPT')));
  });

  test('thermal share text covers empty items, wallet, and balance', () {
    final empty = buildThermalReceiptText(
      _receipt(
        saleNumber: '',
        paymentMethod: 'wallet',
        paymentReference: '',
        servedByName: '',
        items: const [],
        taxAmount: 0,
        discountAmount: 0,
      ),
    );
    expect(empty, contains('No items.'));
    expect(empty, contains('Paid from customer wallet.'));
    expect(empty, contains('Wallet'));
    expect(empty, contains('OMUWENGA SUPPLIERS'));

    final owed = buildThermalReceiptText(
      _receipt(
        paymentMethod: 'card',
        amountPaid: 40,
        total: 116,
        change: 0,
        taxRate: 0,
      ),
    );
    expect(owed, contains('Card'));
    expect(owed, contains('Balance (owed)'));
    expect(owed, contains('VAT'));
    expect(owed, isNot(contains('VAT (')));
  });

  test('receipt money, date, quantity and payment labels', () {
    expect(formatReceiptMoney(1234.5), 'Ksh 1,234.50');
    expect(formatReceiptMoney(-10), '-Ksh 10.00');
    expect(formatReceiptDate(null), '');
    expect(
      formatReceiptDate(DateTime.utc(2026, 9, 16, 12, 30)),
      contains('16/09/2026'),
    );
    expect(formatReceiptQuantity(2), '2');
    expect(formatReceiptQuantity(2.5), '2.50');
    expect(receiptPaymentLabel('cash'), 'Cash');
    expect(receiptPaymentLabel('mpesa'), 'M-Pesa');
    expect(receiptPaymentLabel('wallet'), 'Wallet');
    expect(receiptPaymentLabel('card'), 'Card');
    expect(receiptPaymentLabel('bank_transfer'), 'Bank Transfer');
    expect(receiptPaymentLabel(''), 'Paid');
    expect(receiptPaymentLabel('voucher'), 'voucher');
  });

  test('store info falls back to web defaults', () {
    const emptyName = PosSettings(storeName: '  ', receiptFooter: '');
    final info = ReceiptStoreInfo.fromPosSettings(emptyName);
    expect(info.storeName, kDefaultReceiptStoreName);
    expect(info.footer, kDefaultReceiptFooter);

    final branded = ReceiptStoreInfo.fromPosSettings(
      const PosSettings(
        storeName: 'Duka',
        receiptFooter: 'Karibu tena',
        showSku: true,
      ),
    );
    expect(branded.storeName, 'Duka');
    expect(branded.footer, 'Karibu tena');
    expect(branded.showSku, isTrue);
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
      'tax_rate': 16,
      'delivery_cost': 20,
      'items': [
        {
          'product_name': 'Soap',
          'quantity': 1,
          'unit_price': 10,
          'size_name': 'Large',
          'color_name': 'White',
          'product_sku': 'SOAP-1',
        },
      ],
    });
    expect(fromServed.servedByName, 'Amina');
    expect(fromServed.taxRate, 16);
    expect(fromServed.deliveryCost, 20);
    expect(fromServed.items.single.variantLabel, 'Large · White');
    expect(fromServed.items.single.sku, 'SOAP-1');

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

  testWidgets('on-screen thermal receipt matches web share layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ThermalReceiptView(
            receipt: _receipt(
              paymentMethod: 'cash',
              amountPaid: 200,
              change: 84,
              deliveryCost: 15,
            ),
            store: const ReceiptStoreInfo(
              storeName: 'Test Duka',
              header: 'Welcome',
              branchName: 'Westlands',
              address: 'Nairobi CBD',
              phone: '0700111222',
              taxId: 'P051111',
              footer: 'Asante kwa biashara yako.',
              showSku: true,
            ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('TEST DUKA'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Westlands'), findsOneWidget);
    expect(find.text('PIN: P051111'), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Served by'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('SKU-1'), findsOneWidget);
    expect(find.text('VAT (16%)'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Asante kwa biashara yako.'), findsOneWidget);
    expect(find.byKey(const Key('receipt_total')), findsOneWidget);
    final reachUs = tester.widget<OutlinedButton>(
      find.byKey(const Key('receipt_reach_us')),
    );
    reachUs.onPressed?.call();
    await tester.pump();
    expect(find.textContaining('Copied 0718515142'), findsOneWidget);
  });

  testWidgets('thermal receipt empty items and wallet note', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ThermalReceiptView(
          receipt: _receipt(
            paymentMethod: 'wallet',
            paymentReference: '',
            items: const [],
            taxAmount: 0,
            discountAmount: 0,
            servedByName: null,
          ),
        ),
      ),
    );
    expect(find.text('No items.'), findsOneWidget);
    expect(find.text('Paid from customer wallet.'), findsOneWidget);
    expect(find.text('OMUWENGA SUPPLIERS'), findsOneWidget);
  });

  testWidgets('thermal receipt shows balance owed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ThermalReceiptView(
          receipt: _receipt(
            paymentMethod: 'card',
            amountPaid: 20,
            total: 116,
            change: 0,
            taxRate: 0,
            taxAmount: 4,
          ),
        ),
      ),
    );
    expect(find.text('Balance (owed)'), findsOneWidget);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
  });

  testWidgets('receipt page share error and branded header', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: _receipt(customerName: 'Ada'),
          store: const ReceiptStoreInfo(
            storeName: 'Test Duka',
            header: 'Welcome guests',
            branchName: 'Test Duka',
          ),
        ),
      ),
    );
    expect(find.text('TEST DUKA'), findsOneWidget);
    expect(find.text('Welcome guests'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('receipt page print and share exporters', (tester) async {
    var printed = false;
    final release = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: _receipt(),
          onPrint: (receipt, {store = const ReceiptStoreInfo()}) async {
            printed = true;
            await release.future;
          },
          onShare: (receipt, {store = const ReceiptStoreInfo()}) async {
            throw Exception('share boom');
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receipt_download')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    release.complete();
    await tester.pumpAndSettle();
    expect(printed, isTrue);

    await tester.tap(find.byKey(const Key('receipt_share')));
    await tester.pump();
    expect(find.textContaining('Could not create receipt'), findsOneWidget);
  });

  test('plain item lines have no variant parens', () {
    final text = buildThermalReceiptText(
      _receipt(
        items: const [
          CartLine(
            productId: 1,
            name: 'Plain soap',
            sku: '  ',
            unitPrice: 10,
            quantity: 1,
          ),
        ],
      ),
      store: const ReceiptStoreInfo(showSku: true),
    );
    expect(text, contains('Plain soap'));
    expect(text, isNot(contains('Plain soap (')));
  });

  test('long thermal pair wraps instead of overlapping', () {
    final text = buildThermalReceiptText(
      _receipt(saleNumber: 'VERY-LONG-SALE-NUMBER-123456789'),
    );
    expect(text, contains('VERY-LONG-SALE-NUMBER-123456789'));
  });

  test('pdf also builds wallet, empty, and balance variants', () async {
    final wallet = await buildReceiptPdf(
      _receipt(
        paymentMethod: 'wallet',
        items: const [],
        taxAmount: 0,
        discountAmount: 0,
        paymentReference: '',
        servedByName: '',
      ),
      store: const ReceiptStoreInfo(
        storeName: 'Duka',
        header: 'Hi',
        branchName: 'Duka',
        address: 'Town',
        phone: '07',
        taxId: 'P1',
        showSku: true,
      ),
    );
    expect(String.fromCharCodes(wallet.take(4)), '%PDF');

    final owed = await buildReceiptPdf(
      _receipt(
        paymentMethod: 'cash',
        amountPaid: 10,
        total: 116,
        change: 0,
        deliveryCost: 5,
      ),
    );
    expect(String.fromCharCodes(owed.take(4)), '%PDF');

    final change = await buildReceiptPdf(
      _receipt(
        paymentMethod: 'cash',
        amountPaid: 200,
        total: 116,
        change: 84,
        items: const [
          CartLine(
            productId: 3,
            name: 'Plain',
            unitPrice: 116,
            quantity: 1,
          ),
        ],
      ),
    );
    expect(String.fromCharCodes(change.take(4)), '%PDF');
  });
}
