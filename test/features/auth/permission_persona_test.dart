import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionSet', () {
    test('parses grants and canViewDailySales', () {
      final set = PermissionSet.fromJsonList([
        {
          'module': 'sales',
          'action': 'daily_sales',
          'name': 'sales.daily_sales',
        },
        {'module': 'pos', 'action': 'view'},
        {'module': 'customers', 'action': 'view'},
        {'module': 'debt_management', 'action': 'view'},
        {'module': 'debt_management', 'action': 'update'},
      ]);
      expect(set.canViewDailySales, isTrue);
      expect(set.canAccessPos, isTrue);
      expect(set.canViewCustomers, isTrue);
      expect(set.canViewDebtManagement, isTrue);
      expect(set.canUpdateDebtManagement, isTrue);
      expect(set.canCreateCustomers, isFalse);
      expect(set.canUpdateCustomers, isFalse);
      expect(set.has('sales', 'view'), isFalse);
      expect(set.length, 5);
    });

    test('create and update customer grants', () {
      final set = PermissionSet.fromJsonList([
        {'module': 'customers', 'action': 'create'},
        {'module': 'customers', 'action': 'update'},
      ]);
      expect(set.canCreateCustomers, isTrue);
      expect(set.canUpdateCustomers, isTrue);
      expect(
        PermissionSet([
          const PermissionGrant(module: 'sales', action: 'refund'),
        ]).canRefundSales,
        isTrue,
      );
      expect(
        PermissionSet([
          const PermissionGrant(module: 'sales', action: 'rollback'),
        ]).canRollbackSales,
        isTrue,
      );
      expect(PermissionSet(const []).canRollbackSales, isFalse);
    });

    test('canViewSales and Map grants', () {
      final set = PermissionSet.fromJsonList([
        {'module': 'sales', 'action': 'view'},
      ]);
      expect(set.canViewSales, isTrue);
      expect(
        PermissionGrant.fromJson({'module': 'a', 'action': 'b'}).key,
        'a.b',
      );
    });

    test('dispatch and visit-order grants', () {
      final dispatch = PermissionSet.fromJsonList([
        {'module': 'dispatch', 'action': 'view'},
        {'module': 'dispatch', 'action': 'update'},
      ]);
      expect(dispatch.canDispatch, isTrue);
      expect(dispatch.canUpdateDispatch, isTrue);

      final viewOnly = PermissionSet.fromJsonList([
        {'module': 'dispatch', 'action': 'view'},
      ]);
      expect(viewOnly.canDispatch, isTrue);
      expect(viewOnly.canUpdateDispatch, isFalse);

      final updateOnly = PermissionSet.fromJsonList([
        {'module': 'dispatch', 'action': 'update'},
      ]);
      expect(updateOnly.canDispatch, isFalse);
      expect(updateOnly.canUpdateDispatch, isTrue);

      final sales = PermissionSet.fromJsonList([
        {'module': 'sales', 'action': 'view'},
      ]);
      expect(sales.canPlaceVisitOrders, isTrue);

      final posOnly = PermissionSet.fromJsonList([
        {'module': 'pos', 'action': 'view'},
      ]);
      expect(posOnly.canPlaceVisitOrders, isTrue);

      final neither = PermissionSet.fromJsonList([
        {'module': 'delivery', 'action': 'view'},
      ]);
      expect(neither.canPlaceVisitOrders, isFalse);

      final byName = PermissionSet.fromJsonList([
        {'module': '', 'action': '', 'name': 'dispatch.view'},
      ]);
      expect(byName.canDispatch, isTrue);
    });
  });

  group('resolvePersona', () {
    test('super admin and manager and cashier', () {
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'cashier',
            isSuperAdmin: true,
            isAdmin: false,
            isManager: false,
          ),
          permissions: PermissionSet(const []),
        ),
        AppPersona.admin,
      );
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'manager',
            isSuperAdmin: false,
            isAdmin: false,
            isManager: true,
          ),
          permissions: PermissionSet(const []),
        ),
        AppPersona.manager,
      );
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'cashier',
            isSuperAdmin: false,
            isAdmin: false,
            isManager: false,
          ),
          permissions: PermissionSet(const []),
        ),
        AppPersona.cashier,
      );
    });

    test('custom role with daily_sales maps to manager', () {
      final perms = PermissionSet([
        const PermissionGrant(module: 'sales', action: 'daily_sales'),
      ]);
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'custom',
            isSuperAdmin: false,
            isAdmin: false,
            isManager: false,
          ),
          permissions: perms,
        ),
        AppPersona.manager,
      );
    });

    test('isSuperuser flag wins', () {
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'cashier',
            isSuperAdmin: false,
            isAdmin: false,
            isManager: false,
          ),
          permissions: PermissionSet(const []),
          isSuperuser: true,
        ),
        AppPersona.admin,
      );
    });

    test('dispatcher persona from dispatch grants', () {
      final perms = PermissionSet([
        const PermissionGrant(module: 'dispatch', action: 'view'),
        const PermissionGrant(module: 'dispatch', action: 'update'),
      ]);
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'dispatcher',
            isSuperAdmin: false,
            isAdmin: false,
            isManager: false,
          ),
          permissions: perms,
        ),
        AppPersona.dispatcher,
      );
    });

    test('delivery driver persona from delivery grants', () {
      final perms = PermissionSet([
        const PermissionGrant(module: 'delivery', action: 'view'),
        const PermissionGrant(module: 'delivery', action: 'update'),
      ]);
      expect(perms.canAccessDelivery, isTrue);
      expect(perms.canUpdateDelivery, isTrue);
      expect(
        resolvePersona(
          profile: const UserProfileSnapshot(
            role: 'delivery',
            isSuperAdmin: false,
            isAdmin: false,
            isManager: false,
          ),
          permissions: perms,
        ),
        AppPersona.deliveryDriver,
      );
    });
  });
}
