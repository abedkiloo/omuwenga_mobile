import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('engagement and segment API mapping', () {
    expect(EngagementTier.buyer.apiValue, 'buyer');
    expect(EngagementTier.prospect.apiValue, 'prospect');
    expect(BuyerSegment.coolingOff.apiValue, 'at_risk');
    expect(BuyerSegment.coolingOff.label, 'Cooling off');
    expect(EngagementTierX.fromApi('buyer'), EngagementTier.buyer);
    expect(BuyerSegmentX.fromApi('at_risk'), BuyerSegment.coolingOff);
  });

  test('CustomerSummary parses intelligence fields', () {
    final c = CustomerSummary.fromJson({
      'id': 1,
      'name': 'Ann',
      'engagement_tier': 'buyer',
      'buyer_segment': 'champion',
      'purchase_count': 6,
      'lifetime_sales_value': '12000.00',
      'wallet_balance': '0',
    });
    expect(c.isBuyer, isTrue);
    expect(c.buyerSegment, BuyerSegment.champion);
    expect(c.purchaseCount, 6);
    expect(c.lifetimeSalesValue, 12000);
  });

  test('tooltips explain cooling off and champion', () {
    expect(BuyerSegment.coolingOff.tip, contains('31–90'));
    expect(BuyerSegment.champion.tip, contains('10,000'));
    expect(EngagementTier.prospect.badgeTip, contains('never bought'));
  });
}
