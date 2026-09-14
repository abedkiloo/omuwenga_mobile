import 'permission_set.dart';

/// Mobile home persona — store + field agent.
enum AppPersona {
  cashier,
  manager,
  /// Super admin uses manager-style attention home on mobile.
  admin,
  fieldAgent,
  dispatcher,
  deliveryAgent,
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
      !permissions.canAccessAgents &&
      !permissions.canAccessDelivery) {
    return AppPersona.dispatcher;
  }
  if (permissions.canAccessDelivery &&
      !permissions.canAccessPos &&
      !permissions.canAccessAgents) {
    return AppPersona.deliveryAgent;
  }
  if (permissions.canAccessAgents &&
      !permissions.canAccessPos &&
      (profile.role == 'agent' ||
          profile.roleDisplay == 'Field Agent' ||
          profile.role == 'field_agent')) {
    return AppPersona.fieldAgent;
  }
  if (permissions.canAccessAgents && !permissions.canAccessPos) {
    return AppPersona.fieldAgent;
  }
  if (profile.role == 'cashier' || profile.role == 'sales') {
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
    return AppPersona.deliveryAgent;
  }
  if (permissions.canAccessAgents) {
    return AppPersona.fieldAgent;
  }
  return AppPersona.cashier;
}
