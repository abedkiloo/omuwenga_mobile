import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customer_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail keeps call rows and drops a phone field', () {
    final detail = CustomerDetail.fromDetailJson({
      'customer': {
        'id': 7,
        'name': 'Called Duka',
        'phone': '0712000001',
        'engagement_tier': 'buyer',
        'buyer_segment': 'active',
        'typical_goods': ['Sofa legs'],
        'county': 'Nairobi',
        'is_active': true,
      },
      'calls_enabled': true,
      'calls_count': 4,
      'calls': [
        {
          'id': 3,
          'called_on': '16 November',
          'outcome_label': 'Called',
          'called_by': 'Mercy',
          'request_summary': 'Discussed sofa legs',
        },
      ],
    });
    expect(detail.calls.single.summary, 'Discussed sofa legs');
    expect(detail.calls.single.calledBy, 'Mercy');
    expect(detail.callsCount, 4);
    expect(detail.phone, '0712000001');
  });

  testWidgets('three calls stay visible until the rest are opened', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCallHistory(
            count: 4,
            customerType: 'Existing',
            location: 'Nairobi',
            goods: const ['Sofa legs'],
            lastPurchase: '2026-11-16',
            phone: '0712 345 678',
            isActive: true,
            calls: const [
              CustomerCallRecord(
                id: 1,
                calledOn: '16 November',
                outcomeLabel: 'Called',
                calledBy: 'Mercy',
                summary: 'Discussed sofa legs',
              ),
              CustomerCallRecord(
                id: 2,
                calledOn: '09 November',
                outcomeLabel: 'No answer',
                calledBy: 'Brian',
                summary: 'No response',
              ),
              CustomerCallRecord(
                id: 3,
                calledOn: '02 November',
                outcomeLabel: 'Called',
                calledBy: 'Mercy',
                summary: 'Asked about product availability',
              ),
              CustomerCallRecord(
                id: 4,
                calledOn: '01 October',
                outcomeLabel: 'Call later',
                calledBy: 'Mercy',
                summary: 'Older note',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Sofa legs'), findsOneWidget);
    expect(find.text('Existing'), findsOneWidget);
    expect(find.textContaining('Older note'), findsNothing);
    await tester.tap(find.byKey(const Key('customer_call_history_more')));
    await tester.pump();
    expect(find.textContaining('Older note'), findsOneWidget);
  });
}
