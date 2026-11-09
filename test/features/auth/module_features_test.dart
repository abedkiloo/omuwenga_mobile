import 'package:completebyte_pos_mobile/features/auth/domain/module_features.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModuleFeatures', () {
    test('defaults daily sales on when payload is empty', () {
      expect(ModuleFeatures.empty.isDailySalesEnabled, isTrue);
      expect(ModuleFeatures.empty.isRetailPosEnabled, isTrue);
      expect(ModuleFeatures.empty.isCameraBarcodeScanEnabled, isTrue);
      expect(ModuleFeatures.empty.isCollectionPayerDetailsEnabled, isTrue);
    });

    test('reads enabled_modules feature rows', () {
      final features = ModuleFeatures.fromEnabledModules({
        'sales': {
          'is_enabled': true,
          'features': {
            'daily_sales': {'feature_key': 'daily_sales', 'is_enabled': false},
            'pos': {'is_enabled': true},
            'camera_barcode_scan': {'is_enabled': false},
            'sales_history': true,
          },
        },
        'customers': {
          'is_enabled': true,
          'features': {
            'collection_payer_details': {'is_enabled': false},
          },
        },
        'registry': {
          'feature_defaults': {
            'sales': {
              'daily_sales': true,
              'pos': true,
              'camera_barcode_scan': true,
              'sales_history': true,
            },
            'customers': {'collection_payer_details': true},
          },
        },
      });
      expect(features.isDailySalesEnabled, isFalse);
      expect(features.isRetailPosEnabled, isTrue);
      expect(features.isCameraBarcodeScanEnabled, isFalse);
      expect(features.isSalesHistoryEnabled, isTrue);
      expect(features.isCollectionPayerDetailsEnabled, isFalse);
    });

    test('disabled module turns all features off', () {
      final features = ModuleFeatures.fromEnabledModules({
        'sales': {
          'is_enabled': false,
          'features': {
            'daily_sales': {'is_enabled': true},
          },
        },
      });
      expect(features.isDailySalesEnabled, isFalse);
    });
  });

  group('sessionCanViewDailySales', () {
    const manager = UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
      roleDisplay: 'Manager',
    );
    const cashier = UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    );

    test('manager needs sales.daily_sales', () {
      expect(
        sessionCanViewDailySales(
          permissions: PermissionSet([
            const PermissionGrant(module: 'sales', action: 'view'),
          ]),
          profile: manager,
        ),
        isFalse,
      );
      expect(
        sessionCanViewDailySales(
          permissions: PermissionSet([
            const PermissionGrant(module: 'sales', action: 'daily_sales'),
          ]),
          profile: manager,
        ),
        isTrue,
      );
    });

    test('cashier opens own day with sales.view', () {
      expect(
        sessionCanViewDailySales(
          permissions: PermissionSet([
            const PermissionGrant(module: 'sales', action: 'view'),
          ]),
          profile: cashier,
        ),
        isTrue,
      );
    });

    test('module flag off hides for everyone', () {
      final off = ModuleFeatures.fromEnabledModules({
        'sales': {
          'is_enabled': true,
          'features': {
            'daily_sales': {'is_enabled': false},
          },
        },
      });
      expect(
        sessionCanViewDailySales(
          permissions: PermissionSet([
            const PermissionGrant(module: 'sales', action: 'daily_sales'),
          ]),
          profile: manager,
          features: off,
          isSuperuser: true,
        ),
        isFalse,
      );
    });
  });
}
