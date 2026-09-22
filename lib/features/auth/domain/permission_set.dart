class PermissionGrant {
  const PermissionGrant({
    required this.module,
    required this.action,
    this.name,
  });

  final String module;
  final String action;
  final String? name;

  factory PermissionGrant.fromJson(Map<String, dynamic> json) {
    return PermissionGrant(
      module: (json['module'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      name: json['name']?.toString(),
    );
  }

  String get key => '$module.$action';
}

/// Mirrors web `hasPermission` / nav gates in `fe/src/utils/roleAccess.js`.
class PermissionSet {
  PermissionSet(Iterable<PermissionGrant> grants)
    : _keys = {
        for (final g in grants) ...[
          g.key,
          if (g.name != null && g.name!.trim().isNotEmpty) g.name!.trim(),
        ],
      };

  factory PermissionSet.fromJsonList(List<dynamic>? raw) {
    if (raw == null) return PermissionSet(const []);
    final grants = <PermissionGrant>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        grants.add(PermissionGrant.fromJson(item));
      } else if (item is Map) {
        grants.add(PermissionGrant.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return PermissionSet(grants);
  }

  final Set<String> _keys;

  /// Same as FE: `module.action` name or module+action pair.
  bool has(String module, String action) => _keys.contains('$module.$action');

  bool get canViewDailySales => has('sales', 'daily_sales');
  bool get canAccessPos => has('pos', 'view') || has('pos', 'create');
  bool get canViewCustomers => has('customers', 'view');
  bool get canCreateCustomers => has('customers', 'create');
  bool get canUpdateCustomers => has('customers', 'update');
  bool get canViewDebtManagement => has('debt_management', 'view');
  bool get canUpdateDebtManagement => has('debt_management', 'update');
  bool get canViewSales => has('sales', 'view');
  bool get canViewAllSales => has('sales', 'view_all');
  bool get canRefundSales => has('sales', 'refund');

  /// Visit / field orders — normal sales users with POS or sales access.
  bool get canPlaceVisitOrders =>
      canAccessPos || canViewSales || has('sales', 'create');

  /// Field sales list / pack queue — FE nav: dispatch.view.
  bool get canDispatch => has('dispatch', 'view');

  /// Mark ready / assign — FE Field sales: dispatch.update.
  bool get canUpdateDispatch => has('dispatch', 'update');

  bool get canAccessDelivery =>
      has('delivery', 'view') || has('delivery', 'update');
  bool get canUpdateDelivery => has('delivery', 'update');

  bool get isEmpty => _keys.isEmpty;
  int get length => _keys.length;
}
