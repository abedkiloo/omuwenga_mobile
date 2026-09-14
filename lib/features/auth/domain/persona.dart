import 'permission_set.dart';

/// Mobile home persona — store roles only.
enum AppPersona {
  cashier,
  manager,
  /// Super admin uses manager-style attention home on mobile.
  admin,
  dispatcher,
  deliveryDriver,
}

class UserProfileSnapshot {
  const UserProfileSnapshot({
    required this.role,
    required this.isSuperAdmin,
    required this.isAdmin,
    required this.isManager,
    this.roleDisplay,
  });

  final String role;
  final bool isSuperAdmin;
  final bool isAdmin;
  final bool isManager;
  final String? roleDisplay;

  factory UserProfileSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserProfileSnapshot(
        role: 'cashier',
        isSuperAdmin: false,
        isAdmin: false,
        isManager: false,
      );
    }
    return UserProfileSnapshot(
      role: (json['role'] ?? 'cashier').toString(),
      isSuperAdmin: json['is_super_admin'] == true,
      isAdmin: json['is_admin'] == true,
      isManager: json['is_manager'] == true,
      roleDisplay: json['role_display']?.toString(),
    );
  }
}

/// Maps backend profile flags/roles → mobile persona home.
AppPersona resolvePersona({
  required UserProfileSnapshot profile,
  required PermissionSet permissions,
  bool isSuperuser = false,
}) {
  if (isSuperuser || profile.isSuperAdmin) {
    return AppPersona.admin;
  }
  if (profile.isManager || profile.role == 'manager' || profile.role == 'admin') {
    return AppPersona.manager;
  }
  if (permissions.canDispatch &&
      !permissions.canAccessPos &&
      !permissions.canPlaceVisitOrders &&
      !permissions.canAccessDelivery) {
    return AppPersona.dispatcher;
  }
  if (permissions.canAccessDelivery &&
      !permissions.canAccessPos &&
      !permissions.canPlaceVisitOrders) {
    return AppPersona.deliveryDriver;
  }
  if (profile.role == 'cashier' ||
      profile.role == 'sales' ||
      profile.role == 'field_sales') {
    return AppPersona.cashier;
  }
  // Permission heuristic for custom roles.
  if (permissions.canViewDailySales || permissions.has('reports', 'view')) {
    return AppPersona.manager;
  }
  if (permissions.canDispatch) {
    return AppPersona.dispatcher;
  }
  if (permissions.canAccessDelivery) {
    return AppPersona.deliveryDriver;
  }
  return AppPersona.cashier;
}
