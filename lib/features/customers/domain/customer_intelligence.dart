// Purchase intelligence labels (mirrors web / BE engagement_tier + buyer_segment).

enum EngagementTier {
  all,
  buyer,
  prospect,
}

enum BuyerSegment {
  any,
  newBuyer,
  active,
  coolingOff,
  dormant,
  champion,
}

extension EngagementTierX on EngagementTier {
  /// API query value; empty for all.
  String get apiValue => switch (this) {
    EngagementTier.all => '',
    EngagementTier.buyer => 'buyer',
    EngagementTier.prospect => 'prospect',
  };

  String get label => switch (this) {
    EngagementTier.all => 'All customers',
    EngagementTier.buyer => 'Bought from Omuwenga',
    EngagementTier.prospect => 'Registered only',
  };

  String get tip => switch (this) {
    EngagementTier.all => 'Show every duka — buyers and registered-only.',
    EngagementTier.buyer =>
      'Has completed at least one sale from Omuwenga (not fully refunded).',
    EngagementTier.prospect =>
      'In the system but has never completed a purchase from Omuwenga.',
  };

  /// Short badge label on list/detail cards.
  String get badgeLabel => switch (this) {
    EngagementTier.all => '',
    EngagementTier.buyer => 'Buyer',
    EngagementTier.prospect => 'Registered only',
  };

  String get badgeTip => switch (this) {
    EngagementTier.all => '',
    EngagementTier.buyer =>
      'Buyer — has completed at least one sale from Omuwenga.',
    EngagementTier.prospect =>
      'Registered only — in the system but has never bought from Omuwenga.',
  };

  static EngagementTier fromApi(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'buyer':
        return EngagementTier.buyer;
      case 'prospect':
        return EngagementTier.prospect;
      default:
        return EngagementTier.prospect;
    }
  }
}

extension BuyerSegmentX on BuyerSegment {
  String get apiValue => switch (this) {
    BuyerSegment.any => '',
    BuyerSegment.newBuyer => 'new',
    BuyerSegment.active => 'active',
    BuyerSegment.coolingOff => 'at_risk',
    BuyerSegment.dormant => 'dormant',
    BuyerSegment.champion => 'champion',
  };

  String get label => switch (this) {
    BuyerSegment.any => 'Any segment',
    BuyerSegment.newBuyer => 'New buyer',
    BuyerSegment.active => 'Active',
    BuyerSegment.coolingOff => 'Cooling off',
    BuyerSegment.dormant => 'Dormant',
    BuyerSegment.champion => 'Champion',
  };

  String get tip => switch (this) {
    BuyerSegment.any =>
      'Show all buyers regardless of how recently or often they purchase.',
    BuyerSegment.newBuyer =>
      'First purchase only, and that buy was within the last 30 days.',
    BuyerSegment.active =>
      'Bought within the last 30 days (and is not New or Champion).',
    BuyerSegment.coolingOff =>
      'Last purchase was 31–90 days ago — worth a follow-up before they go quiet.',
    BuyerSegment.dormant => 'No purchase for more than 90 days.',
    BuyerSegment.champion =>
      'At least 5 purchases, lifetime sales of KSh 10,000 or more, and bought within 30 days.',
  };

  String get badgeTip => tip;

  static BuyerSegment fromApi(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'new':
        return BuyerSegment.newBuyer;
      case 'active':
        return BuyerSegment.active;
      case 'at_risk':
        return BuyerSegment.coolingOff;
      case 'dormant':
        return BuyerSegment.dormant;
      case 'champion':
        return BuyerSegment.champion;
      default:
        return BuyerSegment.any;
    }
  }

  /// Segments shown as filter chips (excludes [any] when building buyer-only row).
  static const filterOptions = BuyerSegment.values;
}

String formatPurchaseCount(int count) =>
    count == 1 ? '1 purchase' : '$count purchases';
