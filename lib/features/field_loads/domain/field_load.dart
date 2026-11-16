/// Stock a field agent is carrying, and the sales already recorded on it.
///
/// Quantities are whole numbers. Taken and sold are 0–100000. Returned and
/// missing are null until the agent submits a count. Money strings are the
/// API's 2-decimal amounts. This model does not move stock.
class FieldLoadBook {
  const FieldLoadBook({
    required this.canIssue,
    required this.canApprove,
    required this.loads,
  });

  final bool canIssue;
  final bool canApprove;

  /// Newest first, at most 100, matching the API cap.
  final List<FieldLoad> loads;

  factory FieldLoadBook.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    final loads = <FieldLoad>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          loads.add(FieldLoad.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return FieldLoadBook(
      canIssue: json['can_issue'] == true,
      canApprove: json['can_approve'] == true,
      loads: loads,
    );
  }
}

/// One issued load. [status] is `open`, `pending_review`, or `accepted`.
class FieldLoad {
  const FieldLoad({
    required this.id,
    required this.status,
    required this.agentName,
    required this.lines,
    required this.expected,
    required this.collected,
    this.reference = '',
    this.displayStatus = '',
    this.unitsTaken = 0,
    this.unitsSold = 0,
  });

  final int id;
  final String status;
  final String agentName;
  final List<FieldLoadLine> lines;
  final String reference;
  final String displayStatus;
  final int unitsTaken;
  final int unitsSold;

  /// Sale totals on this load, as a decimal string. Empty becomes `0.00`.
  final String expected;
  final String collected;

  bool get isOpen => status == 'open';
  bool get isPending => status == 'pending_review';

  factory FieldLoad.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = <FieldLoadLine>[];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) {
          lines.add(FieldLoadLine.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final money = json['money'];
    final moneyMap = money is Map ? Map<String, dynamic>.from(money) : const {};
    return FieldLoad(
      id: int.tryParse('${json['id']}') ?? 0,
      status: (json['status'] ?? '').toString(),
      agentName: (json['agent_name'] ?? '').toString(),
      lines: lines,
      expected: (moneyMap['expected'] ?? '0.00').toString(),
      collected: (moneyMap['collected'] ?? '0.00').toString(),
      reference: (json['reference'] ?? '').toString(),
      displayStatus: (json['display_status'] ?? '').toString(),
      unitsTaken: int.tryParse('${json['units_taken'] ?? 0}') ?? 0,
      unitsSold: int.tryParse('${json['units_sold'] ?? 0}') ?? 0,
    );
  }
}

/// One product on a load.
class FieldLoadLine {
  const FieldLoadLine({
    required this.id,
    required this.productId,
    this.variantId,
    required this.productName,
    required this.taken,
    required this.sold,
    required this.returned,
    required this.missing,
    required this.stillOut,
    this.unitPrice = '0.00',
    this.available = 0,
  });

  final int id;
  final int productId;
  final int? variantId;
  final String productName;

  /// Units that left the shop. 1–100000.
  final int taken;

  /// Units already sold from this load. 0–[taken].
  final int sold;

  /// Null until a return count is submitted. Then 0 through unsold.
  final int? returned;
  final int? missing;

  /// Taken minus sold minus any returned units.
  final int stillOut;

  /// Catalog price as a decimal string. The server prices the sale.
  final String unitPrice;

  /// Units still available to sell: taken minus sold.
  final int available;

  factory FieldLoadLine.fromJson(Map<String, dynamic> json) {
    int whole(Object? value) => int.tryParse('${value ?? 0}') ?? 0;
    int? optional(Object? value) {
      if (value == null || value == '') return null;
      return int.tryParse('$value');
    }

    return FieldLoadLine(
      id: whole(json['id']),
      productId: whole(json['product_id']),
      variantId: json['variant_id'] == null ? null : whole(json['variant_id']),
      productName: (json['product_name'] ?? '').toString(),
      taken: whole(json['quantity_taken']),
      sold: whole(json['quantity_sold']),
      returned: optional(json['quantity_returned']),
      missing: optional(json['quantity_missing']),
      stillOut: whole(json['still_out']),
      unitPrice: (json['unit_price'] ?? '0.00').toString(),
      available: whole(json['available'] ?? (whole(json['quantity_taken']) - whole(json['quantity_sold']))),
    );
  }
}

/// Body for recording a sale that is already on the load.
///
/// [quantity] must be a whole number from 1 to the unsold remainder.
/// [amountPaid] is a decimal string, 0 through the sale total. [customerId]
/// is required when the sale is not fully paid. [paymentMethod] is `cash`,
/// `mpesa`, `credit`, or `split`. Returns a map the API accepts. Does not
/// change shop stock, and does not create a field order.
Map<String, dynamic> fieldLoadSellBody({
  required int productId,
  int? variantId,
  required int quantity,
  int? customerId,
  required String amountPaid,
  String paymentMethod = 'cash',
  String clientChannel = 'mobile',
}) {
  return {
    'product_id': productId,
    'variant_id': ?variantId,
    'quantity': quantity,
    'customer_id': customerId,
    'amount_paid': amountPaid,
    'payment_method': paymentMethod,
    'client_channel': clientChannel,
  };
}

/// Missing units once the shop has counted what came back.
///
/// Returns null when [returned] is null. Otherwise `taken - sold - returned`.
int? fieldLoadMissing({required int taken, required int sold, int? returned}) {
  if (returned == null) return null;
  return taken - sold - returned;
}
