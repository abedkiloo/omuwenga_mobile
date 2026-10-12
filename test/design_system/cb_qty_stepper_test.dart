import 'package:completebyte_pos_mobile/design_system/chrome/cb_qty_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stepper increments and decrements with +/-', (tester) async {
    var qty = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CbQtyStepper(
                quantity: qty,
                min: 1,
                max: 50,
                decrementKey: const Key('dec'),
                incrementKey: const Key('inc'),
                valueKey: const Key('qty'),
                onChanged: (next) => setState(() => qty = next),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('qty')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('qty'))).data, '1');

    await tester.tap(find.byKey(const Key('inc')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('qty'))).data, '2');

    await tester.tap(find.byKey(const Key('dec')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('qty'))).data, '1');
  });

  testWidgets('tapping qty opens editor to set value like 100', (tester) async {
    var qty = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CbQtyStepper(
                quantity: qty,
                min: 1,
                max: 200,
                valueKey: const Key('qty'),
                onChanged: (next) => setState(() => qty = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('qty')));
    await tester.pumpAndSettle();

    expect(find.text('Set quantity'), findsOneWidget);
    expect(find.byKey(const Key('cb_qty_editor_field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cb_qty_editor_field')), '100');
    await tester.tap(find.byKey(const Key('cb_qty_editor_save')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('qty'))).data, '100');
    expect(qty, 100);
  });

  testWidgets('editor rejects qty above stock max', (tester) async {
    var qty = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CbQtyStepper(
                quantity: qty,
                min: 1,
                max: 10,
                valueKey: const Key('qty'),
                onChanged: (next) => setState(() => qty = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('qty')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cb_qty_editor_field')), '50');
    await tester.tap(find.byKey(const Key('cb_qty_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('Only 10 in stock.'), findsOneWidget);
    expect(qty, 1);
  });
}
