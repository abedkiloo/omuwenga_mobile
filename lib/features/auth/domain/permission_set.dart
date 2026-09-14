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

class PermissionSet {
  PermissionSet(Iterable<PermissionGrant> grants)
      : _keys = {for (final g in grants) g.key};

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

  bool has(String module, String action) => _keys.contains('$module.$action');

  bool get canViewDailySales => has('sales', 'daily_sales');
  bool get canAccessPos => has('pos', 'view') || has('pos', 'create');
  bool get canViewCustomers => has('customers', 'view');
  bool get canCreateCustomers => has('customers', 'create');
  bool get canUpdateCustomers => has('customers', 'update');
  bool get canViewSales => has('sales', 'view');
  bool get canRefundSales => has('sales', 'refund');
  bool get canAccessAgents =>
      has('agents', 'view') || has('agents', 'create') || has('agents', 'update');
  bool get canCreateAgentSites => has('agents', 'create');
  bool get canDispatch => has('dispatch', 'view') || has('dispatch', 'update');
  bool get canUpdateDispatch => has('dispatch', 'update');
  bool get canAccessDelivery =>
      has('delivery', 'view') || has('delivery', 'update');
  bool get canUpdateDelivery => has('delivery', 'update');
  bool get isEmpty => _keys.isEmpty;
  int get length => _keys.length;
}
