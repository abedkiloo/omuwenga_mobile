import 'package:completebyte_pos_mobile/features/auth/domain/module_features.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/field_loads/application/field_loads_controller.dart';
import 'package:completebyte_pos_mobile/features/field_loads/domain/field_load.dart';
import 'package:completebyte_pos_mobile/features/field_loads/presentation/field_loads_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FieldLoadBook _book({required String status, bool canApprove = false}) {
  return FieldLoadBook(
    canIssue: false,
    canApprove: canApprove,
    loads: [
      FieldLoad(
        id: 4,
        status: status,
        agentName: 'Asha',
        expected: '750.00',
        collected: '750.00',
        lines: const [
          FieldLoadLine(
            id: 1,
            productId: 9,
            productName: 'Cups',
            taken: 40,
            sold: 15,
            returned: null,
            missing: null,
            stillOut: 25,
            available: 25,
            unitPrice: '150.00',
          ),
        ],
      ),
    ],
  );
}

class _ReadyLoads extends FieldLoadsController {
  _ReadyLoads(this.book);
  final FieldLoadBook book;

  @override
  FieldLoadsState build() => FieldLoadsState(book: book);
}

void main() {
  test('a load parses money, the gap, and a missing count', () {
    final book = FieldLoadBook.fromJson({
      'can_issue': false,
      'can_approve': true,
      'results': [
        {
          'id': 3,
          'status': 'pending_review',
          'agent_name': 'Asha',
          'money': {'expected': '100.00', 'collected': '40.00'},
          'lines': [
            {
              'id': 8,
              'product_id': 2,
              'product_name': 'Cups',
              'quantity_taken': 40,
              'quantity_sold': 15,
              'quantity_returned': 20,
              'quantity_missing': 5,
              'still_out': 5,
            },
          ],
        },
      ],
    });
    expect(book.canApprove, isTrue);
    expect(book.loads.single.lines.single.missing, 5);
    expect(book.loads.single.collected, '40.00');
    expect(
      fieldLoadSellBody(productId: 2, quantity: 1, amountPaid: '50', customerId: 7),
      {
        'product_id': 2,
        'quantity': 1,
        'customer_id': 7,
        'amount_paid': '50',
        'payment_method': 'cash',
        'client_channel': 'mobile',
      },
    );
    expect(fieldLoadMissing(taken: 20, sold: 10, returned: 8), 2);
    expect(fieldLoadMissing(taken: 20, sold: 10, returned: null), isNull);
  });

  test('the feature flag and permission both have to be on', () {
    final allowed = PermissionSet([
      const PermissionGrant(module: 'agents', action: 'field_load'),
    ]);
    expect(
      sessionCanViewFieldLoads(permissions: allowed),
      isTrue,
    );
    expect(
      sessionCanViewFieldLoads(
        permissions: allowed,
        features: ModuleFeatures.fromEnabledModules({
          'sales': {
            'is_enabled': true,
            'features': {'field_load': false},
          },
        }),
      ),
      isFalse,
    );
    expect(
      sessionCanViewFieldLoads(permissions: PermissionSet(const [])),
      isFalse,
    );
  });

  testWidgets('an open load can record a sale and a return, not accept it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldLoadsProvider.overrideWith(() => _ReadyLoads(_book(status: 'open'))),
        ],
        child: const MaterialApp(home: FieldLoadsPage()),
      ),
    );
    expect(find.text('Cups'), findsWidgets);
    expect(find.text('Available: 25'), findsOneWidget);
    expect(find.text('Record a field sale'), findsOneWidget);
    expect(find.text('Return to shop'), findsOneWidget);
    await tester.tap(find.text('Return to shop'));
    await tester.pumpAndSettle();
    expect(find.text('Submit physical count'), findsOneWidget);
    expect(find.text('Approve reconciliation'), findsNothing);
    expect(find.textContaining('07'), findsNothing);
  });

  testWidgets('a manager can accept a load that is waiting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldLoadsProvider.overrideWith(
            () => _ReadyLoads(_book(status: 'pending_review', canApprove: true)),
          ),
        ],
        child: const MaterialApp(home: FieldLoadsPage()),
      ),
    );
    expect(find.text('Approve reconciliation'), findsOneWidget);
    expect(find.text('Send back for correction'), findsOneWidget);
    expect(find.text('Record a field load sale'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow phone keeps the sale on its own step', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldLoadsProvider.overrideWith(() => _ReadyLoads(_book(status: 'open'))),
        ],
        child: const MaterialApp(home: FieldLoadsPage()),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Record a field sale'), findsOneWidget);
    await tester.tap(find.text('Record a field sale'));
    await tester.pumpAndSettle();
    expect(find.text('Save sale'), findsOneWidget);
    expect(find.text('My available stock'), findsNothing);
    expect(find.text('KES 150'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
