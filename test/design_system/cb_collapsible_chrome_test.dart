import 'package:completebyte_pos_mobile/design_system/chrome/cb_collapsible_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collapsible chrome toggles with caret', (tester) async {
    var collapsed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: CbCollapsibleChrome(
                collapsed: collapsed,
                onToggle: () => setState(() => collapsed = !collapsed),
                collapsedLabel: 'Filters & summary',
                collapsedSummary: '12 sales',
                child: const Text('Expanded chrome body'),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Expanded chrome body'), findsOneWidget);
    expect(find.byKey(const Key('chrome_collapse')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chrome_collapse')));
    await tester.pumpAndSettle();

    expect(find.text('Expanded chrome body'), findsNothing);
    expect(find.text('Filters & summary'), findsOneWidget);
    expect(find.byKey(const Key('chrome_expand')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chrome_expand')));
    await tester.pumpAndSettle();

    expect(find.text('Expanded chrome body'), findsOneWidget);
  });
}
